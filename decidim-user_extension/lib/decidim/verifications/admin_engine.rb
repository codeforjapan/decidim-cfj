# frozen_string_literal: true

module Decidim
  module Verifications
    module UserExtension
      # This is an engine that implements the administration interface for
      # user authorization by user extensoion.
      class AdminEngine < ::Rails::Engine
        isolate_namespace Decidim::Verifications::UserExtension::Admin

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        routes do
          resources :pending_authorizations, only: :index do
            resource :postages, only: :create, as: :postage
          end

          root to: "pending_authorizations#index"
        end
      end
    end
  end
end
