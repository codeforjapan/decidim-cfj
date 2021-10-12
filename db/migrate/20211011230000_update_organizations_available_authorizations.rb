# frozen_string_literal: true

class UpdateOrganizationsAvailableAuthorizations < ActiveRecord::Migration[5.2]

  class MigrationOrganization < ActiveRecord::Base
    self.table_name = "decidim_organizations"
  end

  def up
    rename_available_authorizations("user_extension_authorization_handler", "user_extension")
  end

  def down
    rename_available_authorizations("user_extension", "user_extension_authorization_handler")
  end

  def rename_available_authorizations(old_data, new_data)
    MigrationOrganization.reset_column_information

    MigrationOrganization.transaction do
      MigrationOrganization.find_each do |organization|
        organization.update!(
          available_authorizations: rename_user_extension(organization.available_authorizations, old_data, new_data)
        )
      end
    end
  end

  def rename_user_extension(authorizations, old_data, new_data)
    authorizations.map do |data|
      if data == old_data
        new_data
      else
        data
      end
    end
  end
end
