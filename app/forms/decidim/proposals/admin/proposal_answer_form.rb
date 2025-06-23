# frozen_string_literal: true

module Decidim
  module Proposals
    module Admin
      # A form object to be used when admin users want to answer a proposal.
      # Override to add URL conversion functionality for signed URL fix.
      class ProposalAnswerForm < Decidim::Form
        include TranslatableAttributes
        mimic :proposal_answer

        translatable_attribute :answer, Decidim::Attributes::RichText
        translatable_attribute :cost_report, Decidim::Attributes::RichText
        translatable_attribute :execution_period, Decidim::Attributes::RichText
        attribute :cost, Float
        attribute :internal_state, String

        validates :internal_state, presence: true, inclusion: { in: :proposal_states }
        validates :answer, translatable_presence: true, if: ->(form) { form.state == "rejected" }

        with_options if: :costs_required? do
          validates :cost, numericality: true, presence: true
          validates :cost_report, translatable_presence: true
          validates :execution_period, translatable_presence: true
        end

        alias state internal_state

        def costs_required?
          costs_enabled? && state == "accepted"
        end

        def publish_answer?
          current_component.current_settings.publish_answers_immediately?
        end

        # Override answer setter to convert URLs to Global IDs
        def answer=(value)
          converted_value = convert_rich_text_urls(value)
          super(converted_value)
        end

        private

        def proposal_states
          Decidim::Proposals::ProposalState.where(component: current_component).pluck(:token).map(&:to_s) + ["not_answered"]
        end

        def costs_enabled?
          current_component.current_settings.answers_with_costs?
        end

        # Convert URLs in rich text content to Global IDs
        def convert_rich_text_urls(value)
          return value if value.blank?

          case value
          when Hash
            # For multilingual fields
            value.transform_values { |text| convert_text_urls(text) }
          when String
            # For single language fields
            convert_text_urls(value)
          else
            value
          end
        end

        def convert_text_urls(text)
          return text if text.blank?

          # Convert Rails blob URLs to Global IDs
          text = text.gsub(%r{/rails/active_storage/blobs/[^"'\s]+}) do |match|
            Decidim::Cfj::UrlConverter.rails_url_to_global_id(match) || match
          end

          # Convert S3 URLs to Global IDs
          text.gsub(%r{https://[^/]+\.s3[^/]*\.amazonaws\.com/[^?"'\s]+}) do |match|
            Decidim::Cfj::UrlConverter.s3_url_to_global_id(match) || match
          end
        end
      end
    end
  end
end
