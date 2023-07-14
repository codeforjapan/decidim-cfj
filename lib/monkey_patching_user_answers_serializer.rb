# frozen_string_literal: true

module DecidimFormsUserAnswersSerializerTimezonePatch
  private

  def hash_for(answer)
    timezone = answer.organization&.time_zone || "UTC"

    {
      answer_translated_attribute_name(:id) => answer&.session_token,
      answer_translated_attribute_name(:created_at) => answer&.created_at&.in_time_zone(timezone)&.strftime("%Y-%m-%d %H:%M:%S"),
      answer_translated_attribute_name(:ip_hash) => answer&.ip_hash,
      answer_translated_attribute_name(:user_status) => answer_translated_attribute_name(answer&.decidim_user_id.present? ? "registered" : "unregistered")
    }
  end
end

# force to autoload `UserAnswersSerializer` in decidim-forms gem
Decidim::Forms::UserAnswersSerializer # rubocop:disable Lint/Void

# override `UserAnswersSerializer#hash_for`
module Decidim
  module Forms
    class UserAnswersSerializer
      prepend DecidimFormsUserAnswersSerializerTimezonePatch
    end
  end
end
