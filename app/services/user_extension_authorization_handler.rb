# frozen_string_literal: true

require "digest/md5"

# (Dummy) Authorization Handler for Decidim::UserExtension
#
# In fact, the handler do not handle authorization; Decidim::UserExtension just uses Authorization as metadata storage.
#
class UserExtensionAuthorizationHandler < Decidim::AuthorizationHandler
  validate :check_response

  def metadata
    super
  end

  def unique_id
    nil
  end

  private

  # Internal: Checks for the response status. It is valid only when the `"res"` field
  # is `1`. All other values imply some different kind of errors, but in order to not
  # leak private data we will not care about them.
  #
  # Returns nothing.
  def check_response
    errors.add(:base, :invalid)
  end

  def request_params
    {
    }
  end
end
