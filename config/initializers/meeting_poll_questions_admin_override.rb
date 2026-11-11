# frozen_string_literal: true

# Renders the admin variant of the poll questions only for users who can
# update the poll, with the same check as AnswersController#admin.
#
# Upstream (develop, 0.31, 0.32) only checks :read on the meeting in
# Polls::QuestionsController#index (decidim/decidim#17814, in 0.31.8 and
# 0.32.2) and still renders the admin variant to every reader, so this file
# stays after an upgrade.
Rails.application.config.to_prepare do
  module DecidimMeetingPollQuestionsAdminTemplatePatch
    def index
      enforce_permission_to(:update, :poll, meeting:) if params[:admin]
      super
    end
  end

  Decidim::Meetings::Polls::QuestionsController.prepend(DecidimMeetingPollQuestionsAdminTemplatePatch)
end
