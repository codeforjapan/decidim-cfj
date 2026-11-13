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
              :constraints => ->(request) { Decidim::Admin::OrganizationDashboardConstraint.new(request).matches? },
              :as => "show_user_extension"
        end
      end

      initializer "decidim_user_extension.admin_mount_routes" do
        # 0.32 で decidim のルートは /:locale スコープに入り、スコープ外の /admin/* は
        # decidim-core の catch-all (get "/admin/*rest" -> locale_redirect) に捕まって
        # /:locale/admin/... へリダイレクトされる。スコープ外のままだとその先に
        # 対応するルートが無く 404 になるため、上流と同じスコープ内へマウントする。
        Decidim::Core::Engine.routes do
          extend Decidim::Routes::LocaleRedirects

          scope "/:locale", **locale_scope_options do
            mount Decidim::UserExtension::AdminEngine, at: "/admin/user_extension_details", as: "decidim_admin_user_extension_details"
          end
        end
      end

      def load_seed
        nil
      end
    end
  end
end
