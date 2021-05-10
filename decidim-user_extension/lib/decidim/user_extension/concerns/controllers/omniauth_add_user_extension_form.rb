# frozen_string_literal: true

module Decidim
  module UserExtension
    module Concerns
      module Controllers
        # This module overrides Decidim::Devise::RegistrationController.
        # Adds an instance of UserExtensionForm when initializing RegistrationForm.
        module OmniauthAddUserExtensionForm
          def new
            user_params = params[:user]
            user_params[:user_extension] ||= UserExtensionAuthorizationHandler.new
            @form = form(OmniauthRegistrationForm).from_params(user_params)
          end
        end
      end
    end
  end
end
