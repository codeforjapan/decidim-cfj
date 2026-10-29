# frozen_string_literal: true

# Looks up the resource_id of a component export within the exported component.
module DecidimAdminExportsResourceScopePatch
  EXPORT_RESOURCES = {
    %w(surveys survey_user_responses) => ->(component) { Decidim::Surveys::Survey.where(component:) },
    %w(budgets projects) => ->(component) { Decidim::Budgets::Budget.where(component:) },
    %w(meetings responses) => lambda { |component|
      polls = Decidim::Meetings::Poll.where(meeting: Decidim::Meetings::Meeting.where(component:))
      Decidim::Meetings::Questionnaire.where(questionnaire_for: polls)
    }
  }.freeze

  def create
    enforce_permission_to(:export, :component_data, component:)
    params[:resource_id] = export_resource_id
    super
  end

  private

  def export_resource_id
    resources = EXPORT_RESOURCES[[component.manifest_name, params[:id].to_s]]
    return if resources.nil? || params[:resource_id].blank?

    resources.call(component).find(params[:resource_id].to_s).id
  end
end

Rails.application.config.to_prepare do
  # Fail the boot when an export above is renamed or removed upstream,
  # otherwise its resource_id would silently be dropped.
  DecidimAdminExportsResourceScopePatch::EXPORT_RESOURCES.each_key do |manifest_name, export_name|
    next if Decidim.find_component_manifest(manifest_name)&.export_manifests&.any? { |manifest| manifest.name.to_s == export_name }

    raise "exports_controller_override.rb: export #{manifest_name}/#{export_name} not found"
  end

  Decidim::Admin::ExportsController.prepend(DecidimAdminExportsResourceScopePatch)
end
