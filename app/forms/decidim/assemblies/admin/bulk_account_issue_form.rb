# frozen_string_literal: true

module Decidim
  module Assemblies
    module Admin
      # アセンブリ管理画面の一括アカウント発行の入力を検証し、issuer に渡す instructions へ変換する。
      class BulkAccountIssueForm < Decidim::Form
        mimic :bulk_account_issue

        MAX_ACCOUNTS_PER_REQUEST = 100

        attribute :participant_count, Integer
        attribute :admin_count, Integer

        validate :counts_must_be_non_negative
        validate :at_least_one_account, if: -> { errors.empty? }
        validate :within_request_cap, if: -> { errors.empty? }
        validate :slug_must_fit_id_budget, if: -> { errors.empty? }
        validate :organization_must_have_tos_version, if: -> { errors.empty? }

        def instructions
          [
            instruction("participant", participant_count),
            instruction("admin", admin_count)
          ].select { |instruction| instruction[:count].positive? }
        end

        private

        def instruction(role, count)
          { space_type: "assemblies", space_slug: current_participatory_space.slug, role:, count: count.to_i }
        end

        def total
          participant_count.to_i + admin_count.to_i
        end

        def counts_must_be_non_negative
          return unless participant_count.to_i.negative? || admin_count.to_i.negative?

          errors.add(:base, :negative_counts)
        end

        def at_least_one_account
          return unless total.zero?

          errors.add(:base, :no_accounts)
        end

        def within_request_cap
          return if total <= MAX_ACCOUNTS_PER_REQUEST

          errors.add(:base, :too_many_accounts, max: MAX_ACCOUNTS_PER_REQUEST)
        end

        def slug_must_fit_id_budget
          max = Decidim::BulkSpaceAccountIssuer::MAX_SLUG_LENGTH
          return if current_participatory_space.slug.to_s.downcase.length <= max

          errors.add(:base, :slug_too_long, max:)
        end

        def organization_must_have_tos_version
          return if current_organization.tos_version.present?

          errors.add(:base, :missing_tos_version)
        end
      end
    end
  end
end
