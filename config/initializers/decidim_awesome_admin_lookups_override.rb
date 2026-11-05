# frozen_string_literal: true

# Resolves the records that the decidim_awesome admin looks up by id within the
# current organization, as the rest of its admin already does through
# AwesomeConfig.find_or_initialize_by(organization:).
Rails.application.config.to_prepare do
  module DecidimAwesomeOrganizationConstraints
    def self.for(organization)
      Decidim::DecidimAwesome::ConfigConstraint
        .joins(:awesome_config)
        .where(decidim_awesome_config: { decidim_organization_id: organization&.id })
    end
  end

  module DecidimAwesomeConstraintsControllerLookupPatch
    private

    def constraint
      @constraint ||= DecidimAwesomeOrganizationConstraints.for(current_organization).find(params[:id])
    end
  end

  # The form id comes from the request body and may differ from the route id
  # the controller resolved.
  module DecidimAwesomeUpdateConstraintLookupPatch
    def call
      return broadcast(:invalid) unless DecidimAwesomeOrganizationConstraints.for(form.current_organization).exists?(id: form.id)

      super
    end
  end

  module DecidimAwesomeConfigControllerLookupPatch
    private

    def users_for(ids_list)
      super(current_organization.users.where(id: ids_list))
    end
  end

  module DecidimAwesomeAdminAuthorizationsLookupPatch
    private

    def user
      @user ||= current_organization.users.find(params[:id])
    end

    def conflict
      @conflict ||= handler.duplicate if handler.unique_id
    end
  end

  module DecidimAwesomeConfigConstraintsHelpersLookupPatch
    def components_list(manifest, slug)
      space = model_for_manifest(manifest)
      return {} unless space&.column_names&.include?("slug")

      participatory_space = space.where(organization: current_organization).find_by(slug:)
      Decidim::Component.where(participatory_space:).to_h do |item|
        [item.id, "#{item.id}: #{translated_attribute(item.name)}"]
      end
    end

    def translate_constraint_value(constraint, key)
      if key.to_sym == :component_id
        component = Decidim::Component.find_by(id: constraint.settings[key])
        return constraint.settings[key] unless component&.organization == current_organization
      end

      super
    end
  end

  Decidim::DecidimAwesome::Admin::ConstraintsController.prepend(DecidimAwesomeConstraintsControllerLookupPatch)
  Decidim::DecidimAwesome::Admin::UpdateConstraint.prepend(DecidimAwesomeUpdateConstraintLookupPatch)
  Decidim::DecidimAwesome::Admin::ConfigController.prepend(DecidimAwesomeConfigControllerLookupPatch)
  Decidim::DecidimAwesome::Admin::AdminAuthorizationsController.prepend(DecidimAwesomeAdminAuthorizationsLookupPatch)
  Decidim::DecidimAwesome::Admin::ConfigConstraintsHelpers.prepend(DecidimAwesomeConfigConstraintsHelpersLookupPatch)
end
