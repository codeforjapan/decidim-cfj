# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Decidim::Proposals::ProposalWizardCreateStepForm
  #
  # minimum title length should be 8
  Decidim::Proposals::ProposalWizardCreateStepForm.validators.each do |validator|
    if validator.instance_of?(ProposalLengthValidator) && # rubocop:disable Style/Next
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
    if validator.instance_of?(ActiveModel::Validations::LengthValidator) && # rubocop:disable Style/Next
       validator.attributes.first.match?(/^title_/)

      fixed_options = validator.options.dup
      fixed_options[:minimum] = 8
      validator.instance_eval do
        @options = fixed_options.freeze
      end
    end
  end

  # load default definitions
  Decidim::Comments::SortedComments # rubocop:disable Lint/Void
  Decidim::Comments::CommentsController # rubocop:disable Lint/Void
  Decidim::Comments::CommentsHelper # rubocop:disable Lint/Void

  module Decidim
    module Comments
      class SortedComments < Decidim::Query
        # override
        def query
          scope = base_scope
                  .includes(:author, :user_group, :up_votes, :down_votes)

          case @options[:order_by]
          when "older"
            order_by_older(scope)
          when "recent"
            order_by_recent(scope)
          when "best_rated"
            order_by_best_rated(scope)
          when "most_discussed"
            order_by_most_discussed(scope)
          else # rubocop:disable Lint/DuplicateBranch
            order_by_older(scope)
          end
        end
      end

      class CommentsController < Decidim::Comments::ApplicationController
        private

        # override
        def order
          params_order = params.fetch(:order, nil)
          if params_order
            cookies["comment_default_order"] = params_order if cookies[Decidim.config.consent_cookie_name].present? # cookies_accepted?
            params_order
          elsif cookies["comment_default_order"] && cookies[Decidim.config.consent_cookie_name].present? # cookies_accepted?
            cookies["comment_default_order"]
          else
            "older"
          end
        end
      end

      module CommentsHelper
        # Override
        def inline_comments_for(resource, options = {})
          return unless resource.commentable?

          cell(
            "decidim/comments/comments",
            resource,
            machine_translations: machine_translations_toggled?,
            single_comment: params.fetch("commentId", nil),
            order: options[:order] || params["orderable"] || cookies["comment_default_order"],
            polymorphic: options[:polymorphic]
          ).to_s
        end
      end
    end
  end

  module Decidim
    module Map
      class DynamicMap < Map::Frontend
        class Builder < Decidim::Map::Frontend::Builder
          # Override
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

  # Fix I18n.transliterate()
  I18n.config.backend.instance_eval do
    @transliterators[:ja] = I18n::Backend::Transliterator.get(->(string) { string })
    @transliterators[:en] = I18n::Backend::Transliterator.get(->(string) { string })
  end
end
