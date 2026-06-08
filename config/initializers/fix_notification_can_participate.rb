# frozen_string_literal: true

# Workaround for Decidim bug where Notification#can_participate?
# delegates unconditionally to resource, but UserGroup (and potentially other
# resource types) do not implement can_participate?.
module FixNotificationCanParticipate
  def can_participate?(user = nil)
    return unless resource.respond_to?(:can_participate?)

    resource.can_participate?(user)
  end
end

Rails.application.config.to_prepare do
  Decidim::Notification.prepend(FixNotificationCanParticipate)
end
