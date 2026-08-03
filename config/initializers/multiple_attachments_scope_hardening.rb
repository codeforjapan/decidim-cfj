# frozen_string_literal: true

# Adds a scope condition to the attachment lookup in
# update_attachment_title_for.
#
# Deliberately narrow, because this prepends onto a decidim-core module shared
# by proposals, collaborative drafts, debates and questionnaire answers:
#
# - `find` is kept rather than `find_by`, so a missing id still raises exactly
#   as upstream does.
# - When no owner can be resolved the original behaviour is used, so the patch
#   can never drop an update that used to succeed.
module MultipleAttachmentsScopeHardening
  private

  def update_attachment_title_for(attachment)
    record = Decidim::Attachment.find(attachment[:id])
    return unless attachment_in_scope?(record)

    record.update(title: title_for(attachment))
  end

  # Decidim derives the right to touch an attachment from the right to edit the
  # record it hangs off, so comparing against that record is the rule this
  # should express. Commands that assign @attached_to before build_attachments
  # runs make it available, and those are checked that way.
  #
  # The rest only assign it in run_after_hooks, leaving documents_attached_to
  # to fall back to the organization. There the record is not knowable yet, so
  # the check drops to the organization: weaker than the rule, but still the
  # tenant boundary, and never stricter than what the command can actually
  # verify.
  def attachment_in_scope?(record)
    owner = documents_attached_to
    return true if owner.blank?
    return record.organization == owner if owner.is_a?(Decidim::Organization)

    record.attached_to == owner
  end
end

Rails.application.config.to_prepare do
  Decidim::MultipleAttachmentsMethods # rubocop:disable Lint/Void

  Decidim::MultipleAttachmentsMethods.prepend(MultipleAttachmentsScopeHardening) unless Decidim::MultipleAttachmentsMethods.include?(MultipleAttachmentsScopeHardening)
end
