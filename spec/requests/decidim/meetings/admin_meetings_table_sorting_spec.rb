# frozen_string_literal: true

require "rails_helper"

# Backport of decidim/decidim#16978 (itself a backport of #16831).
# The meetings admin table's taxonomies column used to sort through the
# non-existent :scope_name key, so it could not sort. It must sort through the
# taxonomies association instead.
# See config/initializers/admin_table_sorting_override.rb and
# app/overrides/decidim/meetings/admin/meetings/_meetings-thead/use_taxonomies_name_sort.html.erb.deface.
RSpec.describe "Meetings admin table sorting" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:component, manifest_name: :meetings, participatory_space: participatory_process) }
  let!(:meeting) { create(:meeting, component:) }

  before do
    host! organization.host
    sign_in admin_user, scope: :user
  end

  it "sorts the taxonomies column through the taxonomies association" do
    get Decidim::EngineRouter.admin_proxy(component).meetings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("taxonomies_name")
    expect(response.body).not_to include("scope_name")
  end
end
