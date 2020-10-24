# frozen_string_literal: true

module Decidim
  # A form object used to handle user registrations
  class UserExtensionForm < Form
    mimic :user_extension

    attribute :address, String
    attribute :birth_year, Integer
    attribute :gender, Integer
    attribute :occupation, String

    validates :address, presence: true, length: { maximum: Decidim::UserExtension.address_length }
    validates :birth_year, presence: true
    validates :gender, inclusion: { in: Decidim::UserExtension::genders }
    validates :occupation, presence: true, length: { maximum: Decidim::UserExtension.occupation_length }
  end
end
