# frozen_string_literal: true

require "rails_helper"

# config/initializers/action_log_missing_resource_type_override.rb の確認。
RSpec.describe "Admin logs with a resource type that no longer exists" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let(:process) { create(:participatory_process, :published, organization:, title: { en: "Existing process" }) }
  let(:logs_path) { "/#{organization.default_locale}/admin/logs" }
  let(:dashboard_path) { "/#{organization.default_locale}/admin" }

  def create_log(resource_type:, title:, action: "create", version: nil)
    log = create(
      :action_log,
      organization:,
      user: admin,
      participatory_space: process,
      component: nil,
      resource: process,
      action:,
      version:,
      extra_data: { resource: { title: } }
    )
    Decidim::ActionLog.where(id: log.id).update_all(resource_type:) # rubocop:disable Rails/SkipsModelValidations
    log
  end

  def diff_values
    Nokogiri::HTML(response.body).css(".logs__log__diff-value").map { |node| node.text.strip }
  end

  before do
    host! organization.host
    sign_in admin, scope: :user
  end

  context "when a log has a resource type whose class no longer exists" do
    before do
      create_log(resource_type: "Decidim::Accountability::TimelineEntry", title: { en: "Removed timeline entry" })
      create_log(resource_type: "Decidim::AssemblyMember", title: { en: "Removed assembly member" })
    end

    it "renders the logs with the recorded resource name" do
      get logs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Removed timeline entry")
      expect(response.body).to include("Removed assembly member")
    end

    it "renders the admin dashboard" do
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Removed timeline entry")
    end

    it "does not load the resource lazily" do
      expect(Decidim::ActionLog.find_by(resource_type: "Decidim::AssemblyMember").resource_lazy).to be_nil
    end
  end

  context "when an update log has a version whose item type no longer exists" do
    let(:version) { PaperTrail::Version.create!(item: process, event: "update", object_changes: { "full_name" => %w(Before After) }) }

    before do
      version.update_column(:item_type, "Decidim::AssemblyMember") # rubocop:disable Rails/SkipsModelValidations
      create_log(resource_type: "Decidim::AssemblyMember", title: { en: "Updated assembly member" }, action: "update", version:)
    end

    it "renders the logs with the diff" do
      get logs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Updated assembly member")
      expect(diff_values).to include("After")
    end
  end

  context "when only the version has an item type that no longer exists" do
    let(:version) do
      PaperTrail::Version.create!(item: process, event: "update", object_changes: { "description" => [{ en: "Before" }, { en: "After" }] })
    end

    before do
      version.update_column(:item_type, "Decidim::Sortitions::Sortition") # rubocop:disable Rails/SkipsModelValidations
      create(:action_log, organization:, user: admin, participatory_space: process, component: nil, resource: process, action: "update", version:)
    end

    it "renders the logs with the diff" do
      get logs_path

      expect(response).to have_http_status(:ok)
      expect(diff_values).to include("After")
    end
  end

  context "when a log has a participatory space type whose class no longer exists" do
    before do
      log = create_log(resource_type: "Decidim::ParticipatoryProcess", title: { en: "Process in a removed space" })
      Decidim::ActionLog.where(id: log.id).update_all(participatory_space_type: "Decidim::Consultation") # rubocop:disable Rails/SkipsModelValidations
    end

    it "renders the logs" do
      get logs_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "when a log has a resource that exists" do
    before do
      create(
        :action_log,
        organization:,
        user: admin,
        participatory_space: process,
        component: nil,
        resource: process,
        action: "update",
        extra_data: { resource: { title: { en: "Recorded title" } } }
      )
    end

    it "links to the resource" do
      get logs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(%r{<a class="logs__log__resource" href="/en/processes/#{process.slug}">Existing process</a>})
    end
  end
end
