# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Extended user attributes definitions for forms
    module FormsDefinitions
      extend ActiveSupport::Concern

      included do
        include ApplicationHelper

        attribute :user_extension, Decidim::UserExtensionForm

        validate :user_extension_form_is_valid
      end

      def map_model(model)
        authorization = Authorization.find_or_initialize_by(decidim_user_id: model.id)
        metadata = authorization.metadata || {}
        self.user_extension = Decidim::UserExtensionForm.from_params(metadata)
      end

      private

      def user_extension_form_is_valid
        return true unless enable_user_extension?
        merge_errors_for("user_extension") if user_extension.invalid?
      end

      def enable_user_extension?
        current_organization.available_authorization_handlers&.include?("user_extension")
      end

      # from https://github.com/andypike/rectify/issues/32
      def merge_errors_for(attr)
        field_prefix = attr
        public_send(attr).errors.messages.each do |field, errors_array|
          errors_array.each do |error_message|
            errors.add("#{field_prefix}_#{field}", error_message)
          end
        end
      end
    end
  end
end
