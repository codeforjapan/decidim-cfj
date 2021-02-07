# frozen_string_literal: true

module Decidim
  module Devise
    # This controller customizes the behaviour of Devise's
    # RegistrationsController so we can specify a custom layout.
    class RegistrationsController < ::Devise::RegistrationsController
      include FormFactory
      include Decidim::DeviseControllers
      include NeedsTosAccepted

      before_action :check_sign_up_enabled
      before_action :configure_permitted_parameters

      invisible_captcha

      def new
        @form = if need_user_extension_by_organization?
                  form(ExtendedRegistrationForm).from_params(
                    user: { sign_up_as: "user" },
                    user_extension: UserExtensionForm.new
                  )
                else
                  form(RegistrationForm).from_params(
                    user: { sign_up_as: "user" }
                  )
                end
      end

      def create
        if need_user_extension_by_organization?
          registration_command = CreateExtendedRegistration
          @form = form(ExtendedRegistrationForm).from_params(params[:user].merge(current_locale: current_locale))
        else
          registration_command = CreateRegistration
          @form = form(RegistrationForm).from_params(params[:user].merge(current_locale: current_locale))
        end

        registration_command.call(@form) do
          on(:ok) do |user|
            if user.active_for_authentication?
              set_flash_message! :notice, :signed_up
              sign_up(:user, user)
              respond_with user, location: after_sign_up_path_for(user)
            else
              set_flash_message! :notice, :"signed_up_but_#{user.inactive_message}"
              expire_data_after_sign_in!
              respond_with user, location: after_inactive_sign_up_path_for(user)
            end
          end

          on(:invalid) do
            flash.now[:alert] = @form.errors[:base].join(", ") if @form.errors[:base].any?
            render :new
          end
        end
      end

      protected

      def check_sign_up_enabled
        redirect_to new_user_session_path unless current_organization.sign_up_enabled?
      end

      def configure_permitted_parameters
        if need_user_extension_by_organization?
          devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :tos_agreement, user_extension: [:address, :birth_year, :occupation, :gender]])
        else
          devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :tos_agreement])
        end
      end

      # Called before resource.save
      def build_resource(hash = nil)
        super(hash)
        resource.organization = current_organization
      end

      def need_user_extension_by_organization?
        current_organization.available_authorization_handlers&.include?("user_extension")
      end
    end
  end
end
