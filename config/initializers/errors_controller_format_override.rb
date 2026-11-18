# frozen_string_literal: true

# Renders the error pages as HTML whatever format was requested. The error
# templates exist only in HTML, so rendering them for a missing .css, .png or
# .xml raised in the exceptions app and turned the 404 into a 500.
Rails.application.config.to_prepare do
  Decidim::ErrorsController.class_eval do
    prepend_before_action { request.format = :html }
  end
end
