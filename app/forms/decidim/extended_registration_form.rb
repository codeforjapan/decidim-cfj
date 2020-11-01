# frozen_string_literal: true

module Decidim
  # A form object used to handle user registrations
  class ExtendedRegistrationForm < Decidim::RegistrationForm
    attribute :user_extension, Decidim::UserExtensionForm

    validate :user_extension_form_is_valid

    private

    def user_extension_form_is_valid
      merge_errors_for("user_extension") if user_extension.invalid?
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
