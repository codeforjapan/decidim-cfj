# frozen_string_literal: true

module Decidim
  module UserExtension
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::UserExtension::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        namespace :officializations do
          get "user_extensions/:user_id" => "user_extensions#show",
              constraints: (->(request) { Decidim::Admin::OrganizationDashboardConstraint.new(request).matches? }),
              as: "show_user_extension"
        end
      end

      initializer "decidim_user_extension.admin_mount_routes" do
        Decidim::Core::Engine.routes do
          mount Decidim::UserExtension::AdminEngine, at: "/admin/user_extension", as: "decidim_user_extension"
        end
      end

      initializer "decidim_user_extension.admin_engine_additions" do
        Decidim::Admin::ApplicationController.class_eval do
          include Decidim::UserExtension::Concerns::Controllers::NeedsUserExtension
        end
      end

      def load_seed
        nil
      end
    end
  end
end
