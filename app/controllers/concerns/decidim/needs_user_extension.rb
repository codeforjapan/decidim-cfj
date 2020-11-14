# frozen_string_literal: true

require "active_support/concern"

module Decidim
  # A concern with the features needed when user exntesions are not registered
  module NeedsUserExtension
    extend ActiveSupport::Concern

    ALLOWS_WITHOUT_USER_EXTENSION = %w(account homepage pages tos)

    included do
      before_action :needs_user_extension
    end

    private

    def needs_user_extension
      logger.info("controller_name: #{controller_name}")
      return true unless current_user
      return true if ALLOWS_WITHOUT_USER_EXTENSION.include?(controller_name)
      metadata = authorization.attributes["metadata"] || {}

      ## TODO: validate all metadata; only exsistance now
      if !metadata["real_name"] || !metadata["address"] || !metadata["birth_year"] || !metadata["gender"]
        flash[:error] = t("errors.messages.needs_user_extension")
        redirect_to decidim.account_path
      end
    end

    def authorization
      @authorization ||= Decidim::Authorization.find_or_initialize_by(
        user: current_user,
        name: "user_extension"
      )
    end
  end
end
