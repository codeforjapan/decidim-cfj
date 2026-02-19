# frozen_string_literal: true

Rails.application.config.to_prepare do
  # load default definitions
  Decidim::Comments::CommentsController # rubocop:disable Lint/Void
  Decidim::Comments::CommentsHelper # rubocop:disable Lint/Void

  module Decidim
    module Comments
      class CommentsController < Decidim::Comments::ApplicationController
        private

        # override
        def order
          params_order = params.fetch(:order, nil)

          ## XXX `"null"` is invalid, it should be `nil`
          params_order = nil if params_order == "null"

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
          )
        end
      end
    end
  end

  # ----------------------------------------

  module DecidimFormsUserAnswersSerializerTimezonePatch
    private

    def hash_for(answer)
      timezone = answer.organization&.time_zone || "UTC"

      {
        answer_translated_attribute_name(:id) => answer&.session_token,
        answer_translated_attribute_name(:created_at) => (answer&.created_at ? answer.created_at.in_time_zone(timezone).strftime("%Y-%m-%d %H:%M:%S") : nil),
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

  # Insert `app/views` into Cell::ViewModel.view_paths to load application's views
  Cell::ViewModel.view_paths.insert(1, Rails.root.join("app/views"))

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

  # ---------------------------------
  # support logo for mobile
  Decidim::Organization.class_eval do
    has_one_attached :mobile_logo
    validates_upload :mobile_logo, uploader: Decidim::OrganizationMobileLogoUploader
  end

  Decidim::Admin::UpdateOrganizationAppearance.class_eval do
    fetch_file_attributes :mobile_logo
  end

  Decidim::Admin::OrganizationAppearanceForm.class_eval do
    attribute :mobile_logo
    attribute :remove_mobile_logo, Decidim::AttributeObject::TypeMap::Boolean, default: false

    validates :mobile_logo, passthru: { to: Decidim::Organization }
  end

  # CloudFrontロゴヘルパーをCellクラスに追加
  Cell::ViewModel.class_eval do
    include Decidim::CloudfrontLogoHelper
  end

  # CloudFrontロゴヘルパーをメーラーに追加
  Decidim::ApplicationMailer.class_eval do
    helper Decidim::CloudfrontLogoHelper
  end

  # ----------------------------------------
  # Add nickname input field to registration form and omniauth registration form

  # Patch RegistrationForm to include nickname field
  Decidim::RegistrationForm.class_eval do
    attribute :nickname, String

    validates :nickname, presence: true, format: { with: Decidim::User::REGEXP_NICKNAME }
    validates :nickname, length: { maximum: Decidim::User.nickname_max_length }
    validate :nickname_unique_in_organization

    # Override the nickname method to use the input value instead of generated one
    def nickname
      # Use the attribute value directly, don't call the original method
      attributes[:nickname].presence || generate_nickname(name, current_organization)
    end

    private

    def nickname_unique_in_organization
      return if nickname.blank? || nickname.strip.empty?

      errors.add(:nickname, :taken) if Decidim::UserBaseEntity.exists?(nickname: nickname.strip, organization: current_organization)
    end
  end

  # Patch RegistrationsController to permit nickname parameter
  Decidim::Devise::RegistrationsController.class_eval do
    private

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :tos_agreement, :nickname])
    end
  end

  # Patch RegistrationForm to include nickname field
  Decidim::OmniauthRegistrationForm.class_eval do
    validates :nickname, presence: true, format: { with: Decidim::User::REGEXP_NICKNAME }
    validates :nickname, length: { maximum: Decidim::User.nickname_max_length }
    validate :nickname_unique_in_organization

    private

    def nickname_unique_in_organization
      return if nickname.blank? || nickname.strip.empty?

      errors.add(:nickname, :taken) if Decidim::UserBaseEntity.exists?(nickname: nickname.strip, organization: current_organization)
    end
  end

  # ----------------------------------------

  # Fix CommentSerializer NoMethodError when author is deleted
  # cf. https://github.com/decidim/decidim/pull/13592 (comments が修正漏れ)
  module DecidimCommentsCommentSerializerNilAuthorPatch
    def serialize
      {
        id: resource.id,
        created_at: resource.created_at,
        body: resource.body.values.first,
        locale: resource.body.keys.first,
        author: {
          id: resource.author.try(:id),
          name: resource.author.try(:name)
        },
        alignment: resource.alignment,
        depth: resource.depth,
        user_group: {
          id: resource.user_group.try(:id),
          name: resource.user_group.try(:name) || empty_translatable
        },
        commentable_id: resource.decidim_commentable_id,
        commentable_type: resource.decidim_commentable_type,
        root_commentable_url:
      }
    end
  end

  Decidim::Comments::CommentSerializer # rubocop:disable Lint/Void

  module Decidim
    module Comments
      class CommentSerializer
        prepend DecidimCommentsCommentSerializerNilAuthorPatch
      end
    end
  end
end
