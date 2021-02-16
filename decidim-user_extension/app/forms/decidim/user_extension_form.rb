# frozen_string_literal: true

module Decidim
  # A form object used to handle user registrations
  class UserExtensionForm < AuthorizationHandler
    REAL_NAME_LENGTH = 100
    ADDRESS_LENGTH = 255
    OCCUPATION_LENGTH = 100
    GENDERS = {
      0 => :not_known,
      1 => :male,
      2 => :female,
      9 => :not_applicable
    }.freeze

    def self.real_name_length
      REAL_NAME_LENGTH
    end

    def self.address_length
      ADDRESS_LENGTH
    end

    def self.occupation_length
      OCCUPATION_LENGTH
    end

    attribute :real_name, String
    attribute :address, String
    attribute :birth_year, Integer
    attribute :gender, Integer
    attribute :occupation, String

    validates :real_name, presence: true, length: { maximum: Decidim::UserExtensionForm.real_name_length }
    validates :address, presence: true, length: { maximum: Decidim::UserExtensionForm.address_length }
    validates :birth_year, presence: true, format: /\A[12][0-9]{3}\z/
    validates :gender, inclusion: { in: GENDERS.keys }
    validates :occupation, length: { maximum: Decidim::UserExtensionForm.occupation_length }

    # real_name && address && birth_year should be unique??
    def unique_id
      Digest::MD5.hexdigest(
        "#{address}-#{birth_year}-#{real_name}-#{Rails.application.secrets.secret_key_base}"
      )
    end

    private

    def duplicates
      return [] if user.blank?

      super
    end
  end
end
