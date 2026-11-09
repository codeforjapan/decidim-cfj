# frozen_string_literal: true

# Applies the :read permission of a meeting to its calendar file, its versions
# and its poll questions.
#
# Not needed once Decidim is 0.31.8 or newer in 0.31, or 0.32.2 or newer.
# The other meeting overrides cover the paths that upstream leaves unchanged
# and stay after this file is removed.
Rails.application.config.to_prepare do
  module DecidimMeetingCalendarReadPatch
    def meeting_calendar
      enforce_permission_to(:read, :meeting, meeting:)
      super
    end
  end

  module DecidimMeetingVersionsReadPatch
    def show
      enforce_permission_to(:read, :meeting, meeting: versioned_resource)
      super
    end
  end

  module DecidimMeetingPollQuestionsReadPatch
    def index
      enforce_permission_to(:read, :meeting, meeting:)
      super
    end
  end

  Decidim::Meetings::CalendarsController.prepend(DecidimMeetingCalendarReadPatch)
  Decidim::Meetings::VersionsController.prepend(DecidimMeetingVersionsReadPatch)
  Decidim::Meetings::Polls::QuestionsController.prepend(DecidimMeetingPollQuestionsReadPatch)
end
