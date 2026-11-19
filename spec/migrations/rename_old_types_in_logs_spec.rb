# frozen_string_literal: true

require "rails_helper"
require "decidim/accountability/test/factories"
require Rails.root.join("db/migrate/20261119120000_rename_old_types_in_logs.rb").to_s

RSpec.describe RenameOldTypesInLogs, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:accountability_component, participatory_space: process) }
  let(:milestone) { create(:milestone, result: create(:result, component:)) }
  let(:version) { PaperTrail::Version.create!(item: milestone, event: "update", object_changes: { "title" => [{ en: "Before" }, { en: "After" }] }) }
  let!(:log) do
    create(:action_log, organization:, user: admin, participatory_space: process, component:, resource: milestone, action: "update", version:)
  end

  before do
    # rubocop:disable Rails/SkipsModelValidations
    Decidim::ActionLog.where(id: log.id).update_all(resource_type: "Decidim::Accountability::TimelineEntry")
    version.update_column(:item_type, "Decidim::Accountability::TimelineEntry")
    # rubocop:enable Rails/SkipsModelValidations
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(:up) }
  end

  it "renames the old types" do
    expect(log.reload.resource_type).to eq("Decidim::Accountability::Milestone")
    expect(version.reload.item_type).to eq("Decidim::Accountability::Milestone")
  end

  it "presents the log as a milestone" do
    host! organization.host
    sign_in admin, scope: :user

    get "/#{organization.default_locale}/admin/logs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("updated the")
    expect(response.body).to include("milestone")
  end

  it "restores the old types on rollback" do
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(:down) }

    expect(log.reload.resource_type).to eq("Decidim::Accountability::TimelineEntry")
    expect(version.reload.item_type).to eq("Decidim::Accountability::TimelineEntry")
  end
end
