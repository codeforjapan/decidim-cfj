# frozen_string_literal: true

# Override Decidim models to use Global IDs in rich text fields for admin editing
# This prevents signed S3 URLs from being displayed and saved in the admin interface

Rails.application.config.to_prepare do
  # Skip this override in test environments to avoid method conflicts
  # The form-level conversion will handle URL transformation
  next if Rails.env.test?

  # Patch blog posts
  if defined?(Decidim::Blogs::Post)
    Decidim::Blogs::Post.class_eval do
      include Decidim::Cfj::GlobalIdRenderer

      # Only override if the method exists and hasn't been overridden yet
      if method_defined?(:body) && !method_defined?(:body_without_global_ids)
        # Store original accessors
        alias_method :body_without_global_ids, :body
        alias_method :body_without_global_ids=, :body=

        # Override getter to convert URLs to Global IDs when displaying
        def body
          render_with_global_ids(:body)
        end

        # Override setter to convert URLs to Global IDs when saving
        def body=(value)
          self.body_without_global_ids = convert_urls_to_global_ids(value)
        end
      end
    end
  end

  # Patch proposals
  if defined?(Decidim::Proposals::Proposal)
    Decidim::Proposals::Proposal.class_eval do
      include Decidim::Cfj::GlobalIdRenderer

      # Only override if the method exists and hasn't been overridden yet
      if method_defined?(:body) && !method_defined?(:body_without_global_ids)
        # Store original accessors
        alias_method :body_without_global_ids, :body
        alias_method :body_without_global_ids=, :body=

        # Override getter to convert URLs to Global IDs when displaying
        def body
          render_with_global_ids(:body)
        end

        # Override setter to convert URLs to Global IDs when saving
        def body=(value)
          self.body_without_global_ids = convert_urls_to_global_ids(value)
        end
      end
    end
  end
end
