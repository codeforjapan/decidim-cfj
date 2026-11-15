# frozen_string_literal: true

require "rails_helper"

# decidim/decidim#16978 (itself a backport of #16831) で上流が修正した挙動。
# taxonomies 列は存在しない :scope_name ではなく taxonomies 関連でソートする。
# 0.30 では独自のバックポートで対応していたが 0.31 で上流に入ったため撤去済み。
# 上流側の退行を検知するために spec だけ残す。
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
