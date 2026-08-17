# frozen_string_literal: true

# Lets admins set the display order of the surveys of a surveys component, both
# in the admin index and in the public list.
#
# Decidim orders neither list: Decidim::Surveys::SurveysController#surveys and
# Decidim::Surveys::Admin::SurveysController#collection have no ORDER BY, so the
# order is whatever Postgres returns and it changes when a survey is updated.
# There is no order attribute in decidim_surveys_surveys either (checked up to
# the develop branch, 0.33.0.dev), so the weights are stored in the
# decidim_cfj_survey_orders side table.
#
# The drag and drop behaviour is the one used by the components table: the
# tbody carries [data-draggable-table] and [data-sort-url], and
# decidim-admin's draggable-table.js sends PUT { order_ids: [...] } to that URL.
#
# Removal steps once decidim_surveys_surveys gets its own order column:
#
#   1. Copy the weights over with a data migration:
#      UPDATE decidim_surveys_surveys s SET weight = o.weight
#      FROM decidim_cfj_survey_orders o
#      WHERE o.decidim_surveys_survey_id = s.id
#   2. Delete this initializer, app/models/decidim/cfj/survey_order.rb,
#      app/commands/decidim/cfj/reorder_surveys.rb and
#      app/views/decidim/surveys/admin/surveys/index.html.erb
#   3. Drop the decidim_cfj_survey_orders table
#
# The route helper is named reorder_surveys_path on purpose: that is the name
# `put :reorder, on: :collection` would generate upstream, so the view needs no
# changes. It cannot be declared inside the surveys resources block from here,
# because the engine declares `resources :surveys` first and PUT /surveys/:id
# (update) would swallow PUT /surveys/reorder.
Decidim::Surveys::AdminEngine.routes.append do
  put "reorder_surveys", to: "surveys#reorder", as: :reorder_surveys
end

Rails.application.config.to_prepare do
  module DecidimCfjSurveysOrderingPatch
    private

    # Copy of Decidim::Surveys::SurveysController#surveys as of v0.30.9, with
    # the ordering added. Check it again when upgrading Decidim.
    def surveys
      paginate(Decidim::Cfj::SurveyOrder.sorted(search.result)).published
    end
  end

  module DecidimCfjSurveysAdminOrderingPatch
    def reorder
      enforce_permission_to(:update, :questionnaire)

      Decidim::Cfj::ReorderSurveys.call(current_component, params[:order_ids]) do
        on(:ok) do
          head :ok
        end

        on(:invalid) do
          head :bad_request
        end
      end
    end

    private

    # Copy of Decidim::Surveys::Admin::SurveysController#collection as of
    # v0.30.9, with the ordering added. Check it again when upgrading Decidim.
    def collection
      @collection ||= Decidim::Cfj::SurveyOrder.for_component(current_component)
    end
  end

  Decidim::Surveys::SurveysController.prepend(DecidimCfjSurveysOrderingPatch)
  Decidim::Surveys::Admin::SurveysController.prepend(DecidimCfjSurveysAdminOrderingPatch)
end
