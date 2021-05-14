# frozen_string_literal: true

module Decidim
  module Verifications
    module UserExtension
      # This is an engine that performs an example user authorization.
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::Verifications::UserExtension

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        routes do
          resource :authorizations, only: [:new, :create, :edit, :update], as: :authorization do
            get :renew, on: :collection
          end

          root to: "authorizations#new"
        end
      end
    end
  end
end
