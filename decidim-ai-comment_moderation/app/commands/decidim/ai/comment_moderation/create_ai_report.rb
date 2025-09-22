# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      # Command to create a Decidim report based on AI analysis
      class CreateAiReport < Decidim::Command
        def initialize(reportable, ai_analysis_result)
          @reportable = reportable
          @ai_analysis_result = ai_analysis_result
        end

        def call
          return broadcast(:invalid) unless should_create_report?

          # Delegate to existing CreateReport command
          Decidim::CreateReport.call(report_form, reportable) do
            on(:ok) do |report|
              log_success(report)
            end

            on(:invalid) do
              log_failure
            end
          end
        end

        private

        attr_reader :reportable, :ai_analysis_result

        def should_create_report?
          reason_mapper.should_report? &&
            !already_reported_by_ai?
        end

        def already_reported_by_ai?
          return false unless reportable.moderation.present?

          ai_user = SystemAiUser.new(reportable.organization).find_or_create_ai_user
          reportable.moderation.reports.exists?(user: ai_user)
        end

        def report_form
          @report_form ||= Decidim::ReportForm.new(
            reason: reason_mapper.decidim_reason,
            details: reason_mapper.report_details
          ).with_context(current_user: ai_user)
        end

        def ai_user
          @ai_user ||= SystemAiUser.new(reportable.organization).find_or_create_ai_user
        end

        def reason_mapper
          @reason_mapper ||= ReasonMapper.new(ai_analysis_result)
        end

        def log_success(report)
          Rails.logger.info(
            "[AI Moderation] Report ##{report.id} created for #{reportable.class.name} ##{reportable.id}: " \
            "reason=#{reason_mapper.decidim_reason}, " \
            "confidence=#{reason_mapper.confidence_percentage}"
          )
        end

        def log_failure
          Rails.logger.warn(
            "[AI Moderation] Failed to create report for #{reportable.class.name} ##{reportable.id}: " \
            "should_report=#{reason_mapper.should_report?}, " \
            "confidence=#{reason_mapper.confidence_percentage}"
          )
        end
      end
    end
  end
end
