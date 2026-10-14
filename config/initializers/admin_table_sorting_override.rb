# frozen_string_literal: true

# Backport of decidim/decidim#16978 (itself a backport of #16831) to v0.30:
# "Fix column sorting in admin tables".
#
# The admin index views and their Filterable concerns already emit sort keys
# such as translated_title, closed, start_time, end_time, taxonomies_name,
# user_moderation_report_count, state_published, valuation_assignments_count,
# report_count and published, but the models' ransackable_attributes did not
# allow them, so clicking a column header either did nothing or raised.
#
# Fixed upstream in 0.31 (#16979) and 0.32 (#16841). release/0.30-stable stopped
# taking backports before it landed (0.30.9 is the last 0.30 release), so it has
# to live here.
#
# Removal: delete this file and its spec once Decidim is 0.31 or newer. The
# guard below fails the boot on any other series so the leftover is noticed.
raise "admin_table_sorting_override.rb and its spec should be removed in 0.31.x (decidim/decidim#16978)" if Gem::Version.new(Decidim::Core.version).segments.first(2) != [0, 30]

Rails.application.config.to_prepare do
  # decidim-core/app/models/decidim/moderation.rb
  Decidim::Moderation.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w(reported_id_string reported_content created_at report_count)
    end
  end

  # decidim-core/app/models/decidim/user_moderation.rb
  Decidim::UserModeration.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w(created_at report_count)
    end
  end

  # decidim-core/app/models/decidim/participatory_space_private_user.rb
  Decidim::ParticipatorySpacePrivateUser.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      return [] unless auth_object&.admin?

      %w(name nickname email invitation_accepted_at last_sign_in_at invitation_sent_at role published)
    end
  end

  # decidim-core/app/models/decidim/user_base_entity.rb
  #
  # Ransack keeps the ransacker registry in a class_attribute, so a subclass
  # that defines a ransacker of its own (Decidim::User does, for
  # invitation_accepted_at/last_sign_in_at) snapshots it and stops inheriting
  # later additions. Register on each concrete class as well, otherwise only
  # Decidim::UserBaseEntity itself would know the new ransackers.
  user_ransackers = proc do |klass|
    klass.ransacker :role do
      Arel.sql(%{CASE WHEN "decidim_users"."admin" = true THEN 'admin' ELSE cast("decidim_users"."roles" as text) END})
    end

    klass.ransacker :user_moderation_report_count do
      query = <<~SQL.squish
        (
            SELECT COALESCE(MAX(decidim_user_moderations.report_count), 0)
            FROM decidim_user_moderations
            WHERE decidim_user_moderations.decidim_user_id = decidim_users.id
        )
      SQL
      Arel.sql(query)
    end
  end

  Decidim::UserBaseEntity.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      base = %w(name email nickname last_sign_in_at created_at)

      return base unless auth_object&.admin?

      base + %w(invitation_sent_at invitation_accepted_at officialized_at role user_moderation_report_count)
    end
  end

  [Decidim::UserBaseEntity, Decidim::User, Decidim::UserGroup].each(&user_ransackers)

  # decidim-meetings/app/models/decidim/meetings/meeting.rb
  Decidim::Meetings::Meeting.class_eval do
    ransacker :closed do
      Arel.sql("(closed_at IS NOT NULL)")
    end

    ransacker_i18n :translated_title, :title

    def self.ransackable_attributes(auth_object = nil)
      base = %w(description id_string search_text title)

      return base unless auth_object&.admin?

      base + %w(is_upcoming closed_at closed start_time end_time translated_title)
    end
  end

  # decidim-proposals/app/models/decidim/proposals/proposal.rb
  Decidim::Proposals::Proposal.class_eval do
    ransacker_i18n :translated_title, :title

    def self.ransackable_attributes(_auth_object = nil)
      %w(
        id_string search_text title translated_title body is_emendation
        comments_count proposal_votes_count published_at proposal_notes_count
        state_published valuation_assignments_count
      )
    end
  end
end
