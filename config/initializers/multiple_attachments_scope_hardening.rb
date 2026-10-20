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
# - When the edited record cannot be resolved (create commands), no existing
#   attachment is in scope.
# - keep_ids only drops ids that are not attachments of the edited record, so
#   attachment_cleanup!, which only iterates those, keeps destroying exactly
#   what it destroyed before.
module MultipleAttachmentsScopeHardening
  private

  def update_attachment_title_for(attachment)
    record = Decidim::Attachment.find(attachment[:id])
    return unless attachment_in_scope?(record)

    record.update(title: title_for(attachment))
  end

  # Keeps the order of the submitted ids, which create_attachments turns into
  # weights.
  def keep_ids
    ids = super
    owner = attachment_owner
    return [] if owner.blank?

    ids & attachments_of(owner).where(id: ids).ids
  end

  # Compares the stored type and id rather than loading attached_to, which
  # would raise for an attachment whose owner class is no longer loaded.
  def attachment_in_scope?(record)
    owner = attachment_owner
    owner.present? && record.attached_to_type == owner.class.polymorphic_name && record.attached_to_id == owner.id
  end

  def attachments_of(owner)
    Decidim::Attachment.where(attached_to_type: owner.class.polymorphic_name, attached_to_id: owner.id)
  end

  # Decidim derives the right to touch an attachment from the right to edit the
  # record it hangs off, so only attachments of that record are in scope.
  #
  # Commands that assign @attached_to before build_attachments runs make the
  # record available that way. Update commands built on
  # Decidim::Commands::UpdateResource only assign it in run_after_hooks, but
  # already hold the record as resource. Create commands have no persisted
  # record yet, so no existing attachment can be theirs.
  #
  # resource is only read from UpdateResource: Decidim::Command forwards
  # unknown methods to the calling controller, which may define its own.
  def attachment_owner
    return @attached_to if @attached_to.present?
    return unless is_a?(Decidim::Commands::UpdateResource)

    resource if resource&.persisted?
  end
end

Rails.application.config.to_prepare do
  Decidim::MultipleAttachmentsMethods

  Decidim::MultipleAttachmentsMethods.prepend(MultipleAttachmentsScopeHardening) unless Decidim::MultipleAttachmentsMethods.include?(MultipleAttachmentsScopeHardening)
end
