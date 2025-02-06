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

  ## load MapHelper in decidim_awesome
  Decidim::DecidimAwesome::MapHelper # rubocop:disable Lint/Void

  module DecidimAwesomeMapHelperPatch
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity:
    def awesome_map_for(components, &)
      return unless map_utility_dynamic

      map = awesome_builder.map_element({ class: "dynamic-map", id: "awesome-map-container" }, &)
      help = content_tag(:div, class: "map__skip-container") do
        content_tag(:p, t("screen_reader_explanation", scope: "decidim.map.dynamic"), class: "sr-only")
      end

      html_options = {
        class: "awesome-map",
        id: "awesome-map",
        data: {
          "components" => components.map do |component|
            {
              id: component.id,
              type: component.manifest.name,
              name: translated_attribute(component.name),
              url: Decidim::EngineRouter.main_proxy(component).root_path,
              amendments: component.manifest.name == :proposals ? Decidim::Proposals::Proposal.where(component:).only_emendations.count : 0
            }
          end.to_json,
          "hide-controls" => settings_source.try(:hide_controls),
          "collapsed" => global_settings.collapse,
          "truncate" => global_settings.truncate || 255,
          "map-center" => global_settings.map_center.presence&.to_json || "",
          "map-zoom" => global_settings.map_zoom || 8,
          "menu-merge-components" => global_settings.menu_merge_components,
          "menu-amendments" => global_settings.menu_amendments,
          "menu-meetings" => global_settings.menu_meetings,
          "menu-categories" => global_settings.menu_categories,
          "menu-hashtags" => global_settings.menu_hashtags,
          "show-not-answered" => step_settings&.show_not_answered,
          "show-accepted" => step_settings&.show_accepted,
          "show-withdrawn" => step_settings&.show_withdrawn,
          "show-evaluating" => step_settings&.show_evaluating,
          "show-rejected" => step_settings&.show_rejected
        }
      }

      content_tag(:div, html_options) do
        content_tag :div, class: "w-full" do
          help + map
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity:
  end

  module Decidim
    module DecidimAwesome
      module MapHelper
        prepend DecidimAwesomeMapHelperPatch
      end
    end
  end

  ## fix `Decidim::Attachment#file_type`
  module DecidimAttachmentFiletypePatch
    def file_type
      url&.split(".")&.last&.downcase&.gsub(/[^A-Za-z0-9].*/, "")
    end
  end

  # force to autoload `` in decidim-core
  Decidim::Attachment # rubocop:disable Lint/Void

  # override `UserAnswersSerializer#hash_for`
  module Decidim
    class Attachment
      prepend DecidimAttachmentFiletypePatch
    end
  end

  ## fix `Decidim::ParticipatoryProcesses::ParticipatoryProcessHelper#process_types`
  module DecidimParticipatoryProcessesProcessTypesPatch
    def process_types
      @process_types ||= Decidim::ParticipatoryProcessType.joins(:processes).where(decidim_organization_id: current_organization.id).distinct
    end
  end

  # force to autoload `ParticipatoryProcessHelper` in decidim-participatry_process
  Decidim::ParticipatoryProcesses::ParticipatoryProcessHelper # rubocop:disable Lint/Void

  # override `process_types`
  module Decidim
    module ParticipatoryProcesses
      module ParticipatoryProcessHelper
        prepend DecidimParticipatoryProcessesProcessTypesPatch
      end
    end
  end

  # ----------------------------------------

  # fix editing the assembly content block
  # cf. https://github.com/decidim/decidim/pull/13544
  module DecidimAssembliesAdminAssemblyLandingPageContentBlocksControllerForV0283Patch
    def parent_assembly
      scoped_resource.parent
    end
  end

  # force to autoload original controller
  Decidim::Assemblies::Admin::AssemblyLandingPageContentBlocksController # rubocop:disable Lint/Void

  # add helper `parent_assembly` as helper
  module Decidim
    module Assemblies
      module Admin
        class AssemblyLandingPageContentBlocksController
          prepend DecidimAssembliesAdminAssemblyLandingPageContentBlocksControllerForV0283Patch

          helper_method :parent_assembly
        end
      end
    end
  end

  # ----------------------------------------

  # Fix I18n.transliterate()
  I18n.config.backend.instance_eval do
    @transliterators[:ja] = I18n::Backend::Transliterator.get(->(string) { string })
    @transliterators[:en] = I18n::Backend::Transliterator.get(->(string) { string })
  end
end
