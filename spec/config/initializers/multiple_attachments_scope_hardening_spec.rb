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
          add_documents: [{ id: unrelated_attachment.id, title: "Renamed" }],
          documents: [unrelated_attachment.id.to_s]
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
            add_documents: [{ id: sibling.id, title: "Renamed" }],
            documents: [sibling.id.to_s]
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

    def rename_payload(record)
      Struct.new(:add_documents, :documents).new(
        [{ id: record.id, title: "Renamed" }.with_indifferent_access],
        [record.id]
      )
    end

    it "updates the title of a document attached to that record" do
      command_class.new(rename_payload(attached_document), target_process).send(:build_attachments)

      expect(translated_attribute(attached_document.reload.title)).to eq("Renamed")
    end
  end

  # keep_ids also decides what document_cleanup! destroys, so the filtering must
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

    let(:form_class) { Struct.new(:add_documents, :documents) }

    it "keeps a document the form still references" do
      command = command_class.new(form_class.new([], [held_document.id]), target_process)

      command.send(:document_cleanup!)

      expect(Decidim::Attachment.exists?(held_document.id)).to be true
    end

    it "destroys a document the form no longer references" do
      command = command_class.new(form_class.new([], []), target_process)

      command.send(:document_cleanup!)

      expect(Decidim::Attachment.exists?(held_document.id)).to be false
    end
  end

  # UpdateDebate and the create commands only assign @attached_to in
  # run_after_hooks, so documents_attached_to still falls back to the
  # organization while build_attachments runs. Renaming an attachment of the
  # record being edited has to keep working in that case.
  describe "when the command has not assigned the record yet" do
    let(:target_process) { create(:participatory_process, organization:) }
    let!(:own_document) do
      create(:attachment, attached_to: target_process, title: { "en" => "Own document" }, weight: 5)
    end

    let(:command_class) do
      Class.new do
        include Decidim::MultipleAttachmentsMethods

        attr_reader :form

        def initialize(form)
          @form = form
        end
      end
    end

    let(:form_class) { Struct.new(:add_documents, :documents, :current_organization) }

    it "renames a document belonging to the current organization" do
      form = form_class.new(
        [{ id: own_document.id, title: "Renamed" }.with_indifferent_access],
        [own_document.id],
        organization
      )

      command_class.new(form).send(:build_attachments)

      expect(translated_attribute(own_document.reload.title)).to eq("Renamed")
    end

    it "does not rename a document belonging to another organization" do
      form = form_class.new(
        [{ id: unrelated_attachment.id, title: "Renamed" }.with_indifferent_access],
        [unrelated_attachment.id],
        organization
      )

      command_class.new(form).send(:build_attachments)

      expect(translated_attribute(unrelated_attachment.reload.title)).to eq("Unrelated document")
    end

    # The check compares organizations, so a document attached to a different
    # record of the same organization is still in scope. Pinned here so the
    # boundary is explicit.
    it "renames a document of another record in the same organization" do
      other_record = create(:participatory_process, organization:)
      sibling = create(:attachment, attached_to: other_record, title: { "en" => "Sibling document" })

      form = form_class.new(
        [{ id: sibling.id, title: "Renamed" }.with_indifferent_access],
        [sibling.id],
        organization
      )

      command_class.new(form).send(:build_attachments)

      expect(translated_attribute(sibling.reload.title)).to eq("Renamed")
    end
  end
end
