# frozen_string_literal: true

module Decidim
  module ContentBlocks
    class ParticipatorySpaceLastActivityCell < BaseCell
      def render_recent_avatars
        return if last_activities_users.blank?

        render :recent_avatars
      end

      def participants_count
        @participants_count ||= activities_query.select(:decidim_user_id).distinct.count
      end

      def activities_query
        @activities_query ||= space_activities_query
      end

      private

      # pass current_user to LastActivity so that activities in private/unpublished spaces are visible to authorized users.
      # Upstream ParticipatorySpaceLastActivity does not pass current_user.
      def space_activities_query
        Decidim::LastActivity.new(resource.organization, current_user:).query.where(participatory_space: resource)
      end

      def ordered_users_with_activities
        @ordered_users_with_activities ||=
          space_activities_query
          .where.not(user: nil)
          .select("decidim_user_id, MAX(decidim_action_logs.created_at)")
          .group("decidim_user_id")
          .reorder("MAX(decidim_action_logs.created_at) DESC")
      end

      def last_activities_users
        @last_activities_users ||= ordered_users_with_activities.limit(max_last_activity_users).map(&:user)
      end

      def max_last_activity_users
        model.settings.try(:max_last_activity_users) || Decidim.default_max_last_activity_users
      end

      def hide_participatory_space = true
    end
  end
end
