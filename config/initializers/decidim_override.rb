# frozen_string_literal: true

require_relative "../../lib/decidim/forms/user_answers_serializer"

Rails.application.config.to_prepare do
  # Decidim::Proposals::ProposalWizardCreateStepForm
  #
  # minimum title length should be 8
  Decidim::Proposals::ProposalWizardCreateStepForm.validators.each do |validator|
    if validator.class == ProposalLengthValidator && # rubocop:disable Style/Next
       validator.attributes.include?(:title)

      fixed_options = validator.options.dup
      fixed_options[:minimum] = 8
      validator.instance_eval do
        @options = fixed_options.freeze
      end
    end
  end

  # Decidim::Proposals::Admin::ProposalForm
  #
  # minimum title length should be 8
  Decidim::Proposals::Admin::ProposalForm.validators.each do |validator|
    if validator.class == ActiveModel::Validations::LengthValidator && # rubocop:disable Style/Next
       validator.attributes.first.match?(/^title_/)

      fixed_options = validator.options.dup
      fixed_options[:minimum] = 8
      validator.instance_eval do
        @options = fixed_options.freeze
      end
    end
  end

  module Decidim
    module Map
      class DynamicMap < Map::Frontend
        class Builder < Decidim::Map::Frontend::Builder
          # Overwrite
          def map_element(html_options = {})
            opts = view_options
            opts["markers"] = opts["markers"].reject { |item| item[:latitude].nil? || item[:latitude].nan? } if opts["markers"].present?
            map_html_options = {
              "data-decidim-map" => opts.to_json,
              # The data-markers-data is kept for backwards compatibility
              "data-markers-data" => opts.fetch(:markers, []).to_json
            }.merge(html_options)

            content = template.capture { yield }.html_safe if block_given?

            template.content_tag(:div, map_html_options) do
              (content || "")
            end
          end
        end
      end
    end
  end
end
