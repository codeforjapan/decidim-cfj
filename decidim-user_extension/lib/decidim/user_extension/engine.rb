# frozen_string_literal: true

require "rails"
require "decidim/core"
require "deface"

module Decidim
  module UserExtension
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::UserExtension

      routes do
        # Add engine routes here
        # resources :user_extension
        # root to: "user_extension#index"
      end

      initializer "decidim_user_extension.assets" do |app|
        app.config.assets.precompile += %w(decidim_user_extension_manifest.js)
      end

      initializer "decidim_user_extension.registration_additions" do
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
      end
    end
  end
end
