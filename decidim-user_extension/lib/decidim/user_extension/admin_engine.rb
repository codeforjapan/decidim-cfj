# frozen_string_literal: true

module Decidim
  module UserExtension
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::UserExtension::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        # Add admin engine routes here
        #namespace :user_extension do
        #  get :foo
        #end
      end

      initializer "decidim_user_extension.admin_mount_routes" do
        Decidim::Core::Engine.routes do
          mount Decidim::UserExtension::AdminEngine, at: "/admin/user_extension", as: "decidim_user_extension"
        end
      end

      def load_seed
        nil
      end
    end
  end
end
