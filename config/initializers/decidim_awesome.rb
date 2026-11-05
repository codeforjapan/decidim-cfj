# frozen_string_literal: true

Decidim::DecidimAwesome.configure do |config|
  config.admin_accountability = []
  config.auto_save_forms = false
  config.validate_title_min_length = 8

  # Maintenance tools under the awesome admin menu that this deployment does
  # not use. `enabled?` treats every value other than :disabled as enabled,
  # including the gem defaults (false / {}), so each one is set explicitly.
  config.hashcash_login = :disabled
  config.hashcash_signup = :disabled
  config.proposal_private_custom_fields = :disabled
  config.link_admin_to_system_admins = :disabled
end
