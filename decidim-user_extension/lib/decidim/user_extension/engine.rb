# frozen_string_literal: true

require "rails"
require "decidim/core"
require "deface"
require "decidim/user_extension/concerns/controllers/needs_user_extension"
require "decidim/user_extension/concerns/controllers/add_user_extension_form"
require "decidim/user_extension/concerns/controllers/omniauth_add_user_extension_form"

module Decidim
  module UserExtension
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::UserExtension

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        # Add engine routes here
        # resources :user_extension
        # root to: "user_extension#index"
      end

      initializer "decidim_user_extension.assets_path" do
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end

      initializer "decidim_user_extension.engine_additions" do
        config.to_prepare do
          Decidim::RegistrationForm.class_eval do
            include UserExtension::FormsDefinitions
          end

          Decidim::OmniauthRegistrationForm.class_eval do
            include UserExtension::FormsDefinitions
          end

          Decidim::AccountForm.class_eval do
            include UserExtension::FormsDefinitions
          end

          Decidim::CreateRegistration.class_eval do
            prepend UserExtension::CreateCommandsOverrides
          end

          Decidim::UpdateAccount.class_eval do
            prepend UserExtension::UpdateCommandsOverrides
          end

          Decidim::DestroyAccount.class_eval do
            prepend UserExtension::DestroyCommandsOverrides
          end

          Decidim::CreateOmniauthRegistration.class_eval do
            prepend UserExtension::CreateOmniauthCommandsOverrides
          end

          DecidimController.class_eval do
            include Decidim::UserExtension::Concerns::Controllers::NeedsUserExtension
          end

          Decidim::Devise::RegistrationsController.class_eval do
            prepend Decidim::UserExtension::Concerns::Controllers::AddUserExtensionForm
          end

          Decidim::Devise::OmniauthRegistrationsController.class_eval do
            prepend Decidim::UserExtension::Concerns::Controllers::OmniauthAddUserExtensionForm
          end
        end
      end
    end
  end
end
