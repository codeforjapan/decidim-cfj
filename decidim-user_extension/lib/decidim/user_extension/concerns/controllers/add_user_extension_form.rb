# frozen_string_literal: true

module Decidim
  module UserExtension
    module Concerns
      module Controllers
        # This module overrides Decidim::Devise::RegistrationController.
        # Adds an instance of UserExtensionForm when initializing RegistrationForm.
        module AddUserExtensionForm
          def new
            @form = form(RegistrationForm).from_params(
              user: { sign_up_as: "user" },
              user_extension: UserExtensionForm.new
              )
          end

          ### Should we overwrite this as well?　It appears to work without it.
          # def configure_permitted_parameters
          #   devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :tos_agreement, user_extension: [:address, :birth_year, :occupation, :gender]])
          # end
        end
      end
    end
  end
end
