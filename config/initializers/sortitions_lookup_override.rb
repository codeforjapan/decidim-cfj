# frozen_string_literal: true

# Resolves the sortition that the admin update and cancel commands act on
# within the current component. The form id comes from the request body and
# may differ from the route id the controller resolved.
#
# Not needed once Decidim includes decidim/decidim#18016.
Rails.application.config.to_prepare do
  module DecidimSortitionsCommandLookupPatch
    private

    def sortition
      @sortition ||= Decidim::Sortitions::Sortition.where(component: form.current_component).find(form.id)
    end
  end

  Decidim::Sortitions::Admin::UpdateSortition.prepend(DecidimSortitionsCommandLookupPatch)
  Decidim::Sortitions::Admin::DestroySortition.prepend(DecidimSortitionsCommandLookupPatch)
end
