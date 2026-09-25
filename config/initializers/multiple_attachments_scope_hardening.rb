# frozen_string_literal: true

# Adds a scope condition to the two places where this module writes to an
# attachment the request identified by id: the title update and the weight
# assignment fed by keep_ids.
#
# Deliberately narrow, because this prepends onto a decidim-core module shared
# by proposals, collaborative drafts, debates and questionnaire answers:
#
# - `find` is kept rather than `find_by`, so a missing id still raises exactly
#   as upstream does.
# - When no owner can be resolved the original behaviour is used, so the patch
#   can never drop an update that used to succeed.
# - keep_ids only ever drops ids that are definitely out of scope, so
#   attachment_cleanup! keeps destroying exactly what it destroyed before.
module MultipleAttachmentsScopeHardening
  private

  def update_attachment_title_for(attachment)
    record = Decidim::Attachment.find(attachment[:id])
    return unless attachment_in_scope?(record)

    record.update(title: title_for(attachment))
  end

  # Drops only ids whose attachment definitely belongs to another organization,
  # so the weight assignment in create_attachments cannot reach them. Anything
  # the check cannot resolve is kept. attachment_cleanup! also reads this, but it
  # only iterates attachments of attachments_attached_to, which always share its
  # organization, so nothing it would have kept can be dropped here.
  def keep_ids
    super.reject { |id| foreign_attachment?(id) }
  end

  def foreign_attachment?(id)
    record = Decidim::Attachment.find_by(id:)
    return false if record.blank?

    !attachment_in_scope?(record)
  end

  # Decidim derives the right to touch an attachment from the right to edit the
  # record it hangs off, so comparing against that record is the rule this
  # should express. Commands that assign @attached_to before build_attachments
  # runs make it available, and those are checked that way.
  #
  # The rest only assign it in run_after_hooks, leaving attachments_attached_to
  # to fall back to the organization. There the record is not knowable yet, so
  # the check drops to the organization: weaker than the rule, but still the
  # tenant boundary, and never stricter than what the command can actually
  # verify.
  def attachment_in_scope?(record)
    owner = attachments_attached_to
    return true if owner.blank?
    return record.organization == owner if owner.is_a?(Decidim::Organization)

    record.attached_to == owner
  end
end

Rails.application.config.to_prepare do
  Decidim::MultipleAttachmentsMethods

  Decidim::MultipleAttachmentsMethods.prepend(MultipleAttachmentsScopeHardening) unless Decidim::MultipleAttachmentsMethods.include?(MultipleAttachmentsScopeHardening)
end
