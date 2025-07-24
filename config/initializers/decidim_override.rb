# frozen_string_literal: true

Rails.application.config.to_prepare do
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
          reload_request = params.fetch(:reload, nil).present?

          if reload_request && params_order.present?
            cookies["comment_default_order"] = params_order if cookies[Decidim.config.consent_cookie_name].present?
            params_order
          elsif cookies["comment_default_order"].present? && cookies[Decidim.config.consent_cookie_name].present?
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
          )
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

  module DecidimAdminPermissionsPatch
    def permissions
      if user &&
         permission_action.scope == :admin &&
         permission_action.subject == :editor_image && (
           user.admin? ||
           user.roles.any? ||
           Decidim::ParticipatoryProcessUserRole.exists?(user:) ||
           Decidim::AssemblyUserRole.exists?(user:) ||
           Decidim::ConferenceUserRole.exists?(user:)
         )
        allow!
      end

      super
    end
  end

  Decidim::Admin::Permissions # rubocop:disable Lint/Void

  module Decidim
    module Admin
      class Permissions < Decidim::DefaultPermissions
        prepend DecidimAdminPermissionsPatch
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

  # ----------------------------------------

  # override `escape_url`
  module DecidimEscapeUriPatch
    def escape_url(external_url)
      uri = Addressable::URI.parse(external_url)
      original_query = uri.query
      normalized_uri = uri.normalize
      normalized_uri.query = original_query
      normalized_uri.to_s
    end
  end

  # force to autoload original controller
  Decidim::LinksController # rubocop:disable Lint/Void

  # add helper `escape_url` as helper
  module Decidim
    class LinksController
      prepend DecidimEscapeUriPatch

      helper_method :escape_url
    end
  end

  # Fix I18n.transliterate()
  I18n.config.backend.instance_eval do
    @transliterators[:ja] = I18n::Backend::Transliterator.get(->(string) { string })
    @transliterators[:en] = I18n::Backend::Transliterator.get(->(string) { string })
  end

  module Decidim
    config_accessor :max_results_options
  end

  Decidim.max_results_options = [6, 9, 12, 15]

  # Insert `app/views` into Cell::ViewModel.view_paths to load application's views
  Cell::ViewModel.view_paths.insert(1, Rails.root.join("app/views"))

  # ----------------------------------------

  # Disable message functionality in profile actions
  module DecidimProfileActionsDisableMessagePatch
    private

    # Override to disable message functionality
    def can_contact_user?
      false
    end
  end

  Decidim::ProfileActionsCell # rubocop:disable Lint/Void

  module Decidim
    class ProfileActionsCell
      prepend DecidimProfileActionsDisableMessagePatch
    end
  end
  # ----------------------------------------

  # add settings for comments
  [:proposals, :debates].each do |component_module|
    manifest = Decidim.find_component_manifest(component_module)
    manifest.settings(:global) do |settings|
      settings.attribute :share_button_disabled, type: :boolean, default: false
      settings.attribute :comment_opinion_disabled, type: :boolean, default: false
    end

    manifest.on(:update) do |component|
      PurgeComponentCacheJob.perform_later(component.id)
    end
  end
end
