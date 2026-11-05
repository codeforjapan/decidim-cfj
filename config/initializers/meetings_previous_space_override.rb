# frozen_string_literal: true

# Resolves the `previous_space` of the meeting redirect notice only among
# visible participatory spaces of the current organization.
Rails.application.config.to_prepare do
  module DecidimMeetingsPreviousSpaceScopePatch
    private

    def previous_space
      return @previous_space if defined?(@previous_space)

      class_name, id = params[:previous_space].to_s.split("#", 2)
      manifest = Decidim.participatory_space_manifests.find { |space_manifest| space_manifest.model_class_name == class_name }
      space = manifest && manifest.participatory_spaces.call(current_organization).find_by(id:)
      @previous_space = (space if space&.visible?)
    end
  end

  Decidim::Meetings::MeetingsController.prepend(DecidimMeetingsPreviousSpaceScopePatch)
end
