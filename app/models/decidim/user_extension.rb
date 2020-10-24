# frozen_string_literal: true

module Decidim
  class UserExtension < ApplicationRecord
    include Decidim::DataPortability

    ADDRESS_LENGTH = 255
    OCCUPATION_LENGTH = 100

    enum gender: {
           not_known: 0,
           male: 1,
           female: 2,
           not_applicable: 9
         }

    belongs_to :user, foreign_key: "decidim_user_id", class_name: "Decidim::User"

    def self.address_length
      ADDRESS_LENGTH
    end

    def self.occupation_length
      OCCUPATION_LENGTH
    end

    validates :address, presence: true, length: { maximum: Decidim::UserExtension.address_length }
    validates :birth_year, presence: true
    validates :gender, presence: true
    validates :occupation, presence: true, length: { maximum: Decidim::UserExtension.occupation_length }

  end
end
