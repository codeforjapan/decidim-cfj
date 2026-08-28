# frozen_string_literal: true

# Backport of decidim/decidim#17332 for Decidim::System::AdminForm.
#
# Fixed upstream in 0.31 (#17341) and 0.32 (#17340). release/0.30-stable stopped
# taking backports before it landed, so it has to live here.
#
# Only the edit-time half is added: the upstream validations already cover
# creation, and duplicating them would show the message twice.
#
# Removal: delete this file and its spec once Decidim is 0.31 or newer. Upstream
# then registers equivalent validations, and leaving these in place would report
# the same error twice, so the guard below fails the boot on any other series.
raise "system_admin_form_override.rb and its spec should be removed in 0.31.x (decidim/decidim#17332)" if Gem::Version.new(Decidim::Core.version).segments.first(2) != [0, 30]

module DecidimCfjSystemAdminFormPasswordConfirmationPatch
  # A confirmation typed on its own is a mismatch too, so it has to trigger the
  # validation.
  def password_submitted?
    password.present? || password_confirmation.present?
  end
end

Rails.application.config.to_prepare do
  Decidim::System::AdminForm # rubocop:disable Lint/Void

  unless Decidim::System::AdminForm.include?(DecidimCfjSystemAdminFormPasswordConfirmationPatch)
    Decidim::System::AdminForm.include(DecidimCfjSystemAdminFormPasswordConfirmationPatch)

    Decidim::System::AdminForm.validates(
      :password,
      confirmation: true,
      if: -> { admin_exists? && password_submitted? }
    )
    Decidim::System::AdminForm.validates(
      :password_confirmation,
      presence: true,
      if: -> { admin_exists? && password_submitted? }
    )
  end
end
