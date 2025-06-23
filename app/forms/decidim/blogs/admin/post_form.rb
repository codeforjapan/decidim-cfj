# frozen_string_literal: true

module Decidim
  module Blogs
    module Admin
      # This class holds a Form to update pages from Decidim's admin panel.
      # Override to add URL conversion functionality for signed URL fix.
      class PostForm < Decidim::Form
        include TranslatableAttributes

        translatable_attribute :title, String
        translatable_attribute :body, Decidim::Attributes::RichText

        attribute :decidim_author_id, Integer
        attribute :published_at, Decidim::Attributes::TimeWithZone

        validates :title, translatable_presence: true
        validates :body, translatable_presence: true
        validate :can_set_author

        def map_model(model)
          self.decidim_author_id = nil if model.author.is_a? Decidim::Organization
        end

        def user_or_group
          @user_or_group ||= Decidim::UserBaseEntity.find_by(
            organization: current_organization,
            id: decidim_author_id
          )
        end

        def author
          user_or_group || current_organization
        end

        # Override body setter to convert URLs to Global IDs
        def body=(value)
          converted_value = convert_rich_text_urls(value)
          super(converted_value)
        end

        private

        def can_set_author
          return if author == current_user.organization
          return if author == current_user
          return if user_groups.include? author
          return if author == post&.author

          errors.add(:decidim_author_id, :invalid)
        end

        def post
          @post ||= Post.find_by(id:)
        end

        def user_groups
          @user_groups ||= Decidim::UserGroups::ManageableUserGroups.for(current_user).verified
        end

        # Convert URLs in rich text content to Global IDs
        def convert_rich_text_urls(value)
          return value if value.blank?

          case value
          when Hash
            # For multilingual fields
            value.transform_values { |text| convert_text_urls(text) }
          when String
            # For single language fields
            convert_text_urls(value)
          else
            value
          end
        end

        def convert_text_urls(text)
          return text if text.blank?

          # Convert Rails blob URLs to Global IDs
          text = text.gsub(%r{/rails/active_storage/blobs/[^"'\s]+}) do |match|
            Decidim::Cfj::UrlConverter.rails_url_to_global_id(match) || match
          end

          # Convert S3 URLs to Global IDs
          text.gsub(%r{https://[^/]+\.s3[^/]*\.amazonaws\.com/[^?"'\s]+}) do |match|
            Decidim::Cfj::UrlConverter.s3_url_to_global_id(match) || match
          end
        end
      end
    end
  end
end
