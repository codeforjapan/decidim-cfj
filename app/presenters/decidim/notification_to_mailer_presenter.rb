# frozen_string_literal: true

module Decidim
  #
  # Decorator for notifications in mail digest
  #
  class NotificationToMailerPresenter < SimpleDelegator
    include Decidim::TranslatableAttributes

    delegate :url_helpers, to: "Decidim::Core::Engine.routes"
    delegate :resource_title, to: :event
    delegate :resource_url, to: :event
    delegate :email_intro, to: :event
    delegate :resource_path, to: :event

    def date_time
      created_at_in_time_zone = created_at.in_time_zone(resource.organization.time_zone)
      if frequency == :daily
        I18n.l(created_at_in_time_zone, format: :time_of_day)
      else
        I18n.l(created_at_in_time_zone, format: :decidim_short)
      end
    end

    private

    def event
      @event ||= event_class.constantize.new(
        resource: resource,
        user: user,
        user_role: user_role,
        event_name: event_name,
        extra: extra
      )
    end

    def frequency
      @frequency ||= user.notifications_sending_frequency
    end
  end
end
