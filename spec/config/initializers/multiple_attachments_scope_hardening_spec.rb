# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::MultipleAttachmentsMethods scoping override" do
  include_context "with a questionnaire answer form"

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

    it "assigns weights from the submitted document ids" do
      expect(submit(build_form(submitted_documents))).to eq(:ok)

      expect(unrelated_attachment.reload.weight).to eq(0)
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

    # Stands in for the commands that include the module and set @attached_to to
    # the record they are editing.
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
      form = Struct.new(:add_documents).new(
        [{ id: attached_document.id, title: "Renamed" }.with_indifferent_access]
      )

      command_class.new(form, target_process).send(:build_attachments)

      expect(translated_attribute(attached_document.reload.title)).to eq("Renamed")
    end
  end
end
