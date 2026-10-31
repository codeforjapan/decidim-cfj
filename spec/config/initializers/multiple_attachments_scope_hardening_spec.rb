# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::MultipleAttachmentsMethods scoping override" do
  include_context "with a questionnaire response form"

  let(:other_organization) { create(:organization) }
  let(:other_process) { create(:participatory_process, organization: other_organization) }
  let!(:unrelated_attachment) do
    create(
      :attachment,
      attached_to: other_process,
      title: { "en" => "Unrelated document" },
      weight: 99
    )
  end

  describe "document ids submitted with an answer" do
    let!(:files_question) do
      create(
        :questionnaire_question,
        questionnaire:,
        question_type: "files",
        mandatory: false,
        position: 0
      )
    end

    let(:submitted_documents) do
      [
        {
          question_id: files_question.id.to_s,
          body: "",
          add_attachments: [{ id: unrelated_attachment.id, title: "Renamed" }],
          attachments: [unrelated_attachment.id.to_s]
        }
      ]
    end

    it "leaves the title of a document not attached to the answer unchanged" do
      expect(submit(build_form(submitted_documents))).to eq(:ok)

      expect(translated_attribute(unrelated_attachment.reload.title)).to eq("Unrelated document")
    end

    it "leaves the weight of a document in another organization unchanged" do
      expect(submit(build_form(submitted_documents))).to eq(:ok)

      expect(unrelated_attachment.reload.weight).to eq(99)
    end

    # This command assigns @attached_to before build_attachments, so the check
    # can compare against the record itself rather than the organization. A
    # document of the same organization but a different record is out of reach.
    it "leaves a document of the same organization but another record unchanged" do
      sibling_process = create(:participatory_process, organization:)
      sibling = create(:attachment, attached_to: sibling_process, title: { "en" => "Sibling document" }, weight: 7)

      form = build_form(
        [
          {
            question_id: files_question.id.to_s,
            body: "",
            add_attachments: [{ id: sibling.id, title: "Renamed" }],
            attachments: [sibling.id.to_s]
          }
        ]
      )

      expect(submit(form)).to eq(:ok)

      sibling.reload
      expect(translated_attribute(sibling.title)).to eq("Sibling document")
      expect(sibling.weight).to eq(7)
    end

    it "leaves the document untouched when no document ids are submitted" do
      form = build_form([{ question_id: files_question.id.to_s, body: "" }])

      expect(submit(form)).to eq(:ok)

      unrelated_attachment.reload
      expect(translated_attribute(unrelated_attachment.title)).to eq("Unrelated document")
      expect(unrelated_attachment.weight).to eq(99)
    end
  end

  describe "document ids belonging to the record being attached to" do
    let(:target_process) { create(:participatory_process, organization:) }
    let!(:attached_document) do
      create(:attachment, attached_to: target_process, title: { "en" => "Attached document" })
    end
    let(:rename_payload) do
      Struct.new(:add_attachments, :attachments).new(
        [{ id: attached_document.id, title: "Renamed" }.with_indifferent_access],
        [attached_document.id]
      )
    end

    # Stands in for the commands that assign @attached_to before calling
    # build_attachments (AnswerQuestionnaire, UpdateProposal, ...).
    let(:command_class) do
      Class.new do
        include Decidim::MultipleAttachmentsMethods

        attr_reader :form

        def initialize(form, attached_to)
          @form = form
          @attached_to = attached_to
        end
      end
    end

    it "updates the title of a document attached to that record" do
      command_class.new(rename_payload, target_process).send(:build_attachments)

      expect(translated_attribute(attached_document.reload.title)).to eq("Renamed")
    end
  end

  # keep_ids also decides what attachment_cleanup! destroys, so the filtering must
  # never remove an id the owner actually holds.
  describe "cleanup of the documents held by the record" do
    let(:target_process) { create(:participatory_process, organization:) }
    let!(:held_document) do
      create(:attachment, :with_pdf, attached_to: target_process, title: { "en" => "Held document" })
    end

    let(:command_class) do
      Class.new do
        include Decidim::MultipleAttachmentsMethods

        attr_reader :form

        def initialize(form, attached_to)
          @form = form
          @attached_to = attached_to
        end
      end
    end

    let(:form_class) { Struct.new(:add_attachments, :attachments) }

    it "keeps a document the form still references" do
      command = command_class.new(form_class.new([], [held_document.id]), target_process)

      command.send(:attachment_cleanup!)

      expect(Decidim::Attachment.exists?(held_document.id)).to be true
    end

    it "destroys a document the form no longer references" do
      command = command_class.new(form_class.new([], []), target_process)

      command.send(:attachment_cleanup!)

      expect(Decidim::Attachment.exists?(held_document.id)).to be false
    end
  end

  # UpdateDebate only assigns @attached_to in run_after_hooks, so the edited
  # record has to be taken from resource while build_attachments runs.
  describe "when an update command has not assigned the record yet" do
    let(:target_process) { create(:participatory_process, organization:) }
    let!(:own_document) do
      create(:attachment, attached_to: target_process, title: { "en" => "Own document" }, weight: 5)
    end
    let(:second_document) { create(:attachment, attached_to: target_process, title: { "en" => "Second document" }) }
    let(:sibling) do
      create(:attachment, attached_to: create(:participatory_process, organization:), title: { "en" => "Sibling document" }, weight: 7)
    end
    # An attachment whose owner class is no longer loaded, e.g. of a removed module.
    let(:orphan) do
      create(:attachment, attached_to: create(:participatory_process, organization:), title: { "en" => "Orphan document" }).tap do |attachment|
        attachment.update_columns(attached_to_type: "Decidim::RemovedModule::Resource") # rubocop:disable Rails/SkipsModelValidations
      end
    end
    let(:submitted) { own_document }
    let(:form) do
      Struct.new(:add_attachments, :attachments, :current_organization).new(
        [{ id: submitted.id, title: "Renamed" }.with_indifferent_access], [submitted.id], organization
      )
    end
    let(:command) { Class.new(Decidim::Commands::UpdateResource) { include Decidim::MultipleAttachmentsMethods }.new(form, target_process) }

    it "renames a document of the record being edited" do
      command.send(:build_attachments)

      expect(translated_attribute(own_document.reload.title)).to eq("Renamed")
    end

    context "with a document of another record in the same organization" do
      let(:submitted) { sibling }

      it "does not rename it" do
        command.send(:build_attachments)

        expect(translated_attribute(sibling.reload.title)).to eq("Sibling document")
        expect(command.send(:keep_ids)).to be_empty
      end
    end

    context "with a document whose owner class is not loaded" do
      let(:submitted) { orphan }

      it "skips it without raising" do
        expect { command.send(:build_attachments) }.not_to raise_error

        expect(translated_attribute(orphan.reload.title)).to eq("Orphan document")
        expect(command.send(:keep_ids)).to be_empty
      end
    end

    context "with several documents of the record" do
      let(:form) do
        Struct.new(:add_attachments, :attachments, :current_organization).new(
          [], [second_document.id, sibling.id, own_document.id], organization
        )
      end

      it "keeps them in the submitted order" do
        expect(command.send(:keep_ids)).to eq([second_document.id, own_document.id])
      end
    end
  end

  # Create commands only assign @attached_to once the record is saved, so while
  # build_attachments runs there is no record whose attachments could be edited.
  describe "when a create command has no record yet" do
    let(:sibling_process) { create(:participatory_process, organization:) }
    let(:sibling) do
      create(:attachment, attached_to: sibling_process, title: { "en" => "Sibling document" }, weight: 7)
    end
    let(:form) do
      Struct.new(:add_attachments, :attachments, :current_organization).new(
        [{ id: sibling.id, title: "Renamed" }.with_indifferent_access], [sibling.id], organization
      )
    end
    let(:command) do
      Class.new(Decidim::Command) do
        include Decidim::MultipleAttachmentsMethods

        def initialize(form)
          @form = form
        end
      end.new(form)
    end
    # Decidim::Command forwards unknown methods to the caller of the block given
    # to .call, here this example. A controller defining resource is the case
    # this stands for.
    let(:resource) { sibling_process }

    before { command.evaluate { nil } }

    it "does not rename a document of the same organization" do
      command.send(:build_attachments)

      expect(translated_attribute(sibling.reload.title)).to eq("Sibling document")
      expect(command.send(:keep_ids)).to be_empty
    end
  end
end
