# frozen_string_literal: true

module MultipleAttachmentsScopeHardening
  private

  def update_attachment_title_for(attachment)
    record = scoped_attachment_for(attachment[:id])
    return if record.blank?

    record.update(title: title_for(attachment))
  end

  def scoped_attachment_for(id)
    owner = documents_attached_to
    return if id.blank? || owner.blank?

    Decidim::Attachment.find_by(id:, attached_to: owner)
  end
end

Rails.application.config.to_prepare do
  Decidim::MultipleAttachmentsMethods # rubocop:disable Lint/Void

  Decidim::MultipleAttachmentsMethods.prepend(MultipleAttachmentsScopeHardening) unless Decidim::MultipleAttachmentsMethods.include?(MultipleAttachmentsScopeHardening)
end
