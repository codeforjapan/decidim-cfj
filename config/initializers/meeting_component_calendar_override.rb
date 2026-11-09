# frozen_string_literal: true

# Limits the component calendar to the meetings that are listed publicly.
Rails.application.config.to_prepare do
  module DecidimMeetingComponentCalendarVisiblePatch
    private

    def filtered_meetings
      super.visible
    end
  end

  Decidim::Meetings::Calendar::ComponentCalendar.prepend(DecidimMeetingComponentCalendarVisiblePatch)
end
