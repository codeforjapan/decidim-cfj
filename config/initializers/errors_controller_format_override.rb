# frozen_string_literal: true

# Responds with the status only to non-HTML requests to the error pages. The
# error templates exist only in HTML, so rendering them for a missing .css,
# .png or .xml raised in the exceptions app and turned the 404 into a 500.
Rails.application.config.to_prepare do
  module DecidimErrorsControllerFormatPatch
    def not_found
      return head(:not_found) unless request.format.html?

      super
    end

    def internal_server_error
      return head(:internal_server_error) unless request.format.html?

      super
    end
  end

  Decidim::ErrorsController.prepend(DecidimErrorsControllerFormatPatch)
end
