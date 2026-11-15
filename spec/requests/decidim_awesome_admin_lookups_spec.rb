# frozen_string_literal: true

require "rails_helper"
require "decidim/decidim_awesome/test/factories"

RSpec.describe "Decidim::DecidimAwesome admin lookups" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization, available_authorizations: ["user_extension"]) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:, password_updated_at: Time.current) }
  let(:other_organization) { create(:organization) }

  before do
    # The organization enables user_extension, which every signed-in user needs.
    create(:authorization, name: "user_extension", user: admin_user,
                           metadata: { real_name: "Admin", address: "Tokyo", birth_year: 1980, gender: 0 })
    host! organization.host
    sign_in admin_user, scope: :user
  end

  describe "constraints" do
    let(:own_config) { create(:awesome_config, organization:, var: "scoped_style_own", value: "") }
    let(:other_config) { create(:awesome_config, organization: other_organization, var: "scoped_style_other", value: "") }
    let!(:own_constraint) { create(:config_constraint, awesome_config: own_config, settings: { "participatory_space_manifest" => "participatory_processes" }) }
    let!(:other_constraint) { create(:config_constraint, awesome_config: other_config, settings: { "participatory_space_manifest" => "participatory_processes" }) }
    let(:changed_settings) { { "participatory_space_manifest" => "assemblies" } }

    it "shows a constraint of the current organization" do
      get decidim_admin_decidim_awesome.constraint_path(own_constraint)

      expect(response).to have_http_status(:ok)
    end

    it "does not show a constraint of another organization" do
      get decidim_admin_decidim_awesome.constraint_path(other_constraint)

      expect(response).to have_http_status(:not_found)
    end

    it "updates a constraint of the current organization" do
      patch decidim_admin_decidim_awesome.constraint_path(own_constraint), params: { constraint: changed_settings }

      expect(response).to have_http_status(:ok)
      expect(own_constraint.reload.settings).to eq(changed_settings)
    end

    it "does not update a constraint of another organization" do
      patch decidim_admin_decidim_awesome.constraint_path(other_constraint), params: { constraint: changed_settings }

      expect(response).to have_http_status(:not_found)

      expect(other_constraint.reload.settings).to eq("participatory_space_manifest" => "participatory_processes")
    end

    it "does not update a constraint of another organization given as the form id" do
      patch decidim_admin_decidim_awesome.constraint_path(own_constraint),
            params: { constraint: changed_settings.merge("id" => other_constraint.id) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(other_constraint.reload.settings).to eq("participatory_space_manifest" => "participatory_processes")
    end

    it "does not destroy a constraint of another organization" do
      delete decidim_admin_decidim_awesome.constraint_path(other_constraint)

      expect(response).to have_http_status(:not_found)

      expect(Decidim::DecidimAwesome::ConfigConstraint).to exist(other_constraint.id)
    end
  end

  describe "component list of a constraint form" do
    let(:own_process) { create(:participatory_process, organization:) }
    let(:other_process) { create(:participatory_process, organization: other_organization, slug: "shared-slug") }
    let!(:own_component) { create(:component, participatory_space: own_process) }
    let!(:other_component) { create(:component, participatory_space: other_process) }

    it "lists the components of a space of the current organization" do
      get decidim_admin_decidim_awesome.new_constraint_path(key: "scoped_style_own",
                                                            participatory_space_manifest: "participatory_processes",
                                                            participatory_space_slug: own_process.slug)

      expect(response.body).to include("value=\"#{own_component.id}\"")
    end

    it "does not list the components of a space of another organization" do
      get decidim_admin_decidim_awesome.new_constraint_path(key: "scoped_style_own",
                                                            participatory_space_manifest: "participatory_processes",
                                                            participatory_space_slug: other_process.slug)

      expect(response.body).not_to include("value=\"#{other_component.id}\"")
    end
  end

  describe "scoped admins page" do
    let(:own_user) { create(:user, :confirmed, organization:) }
    let(:other_user) { create(:user, :confirmed, organization: other_organization) }
    let(:other_component) { create(:component, name: { "en" => "Elsewhere component", "ja" => "Elsewhere component" }, participatory_space: create(:participatory_process, organization: other_organization)) }
    let(:scoped_admin_config) { create(:awesome_config, organization:, var: "scoped_admin_team", value: nil) }

    before do
      create(:awesome_config, organization:, var: "scoped_admins", value: { "team" => [own_user.id.to_s, other_user.id.to_s] })
      create(:config_constraint, awesome_config: scoped_admin_config,
                                 settings: { "participatory_space_manifest" => "participatory_processes", "component_id" => other_component.id.to_s })
    end

    it "lists users of the current organization only" do
      get decidim_admin_decidim_awesome.config_path(:admins)

      expect(response.body).to include(own_user.email)
      expect(response.body).not_to include(other_user.email)
    end

    it "does not show the name of a component of another organization" do
      get decidim_admin_decidim_awesome.config_path(:admins)

      expect(response.body).not_to include("Elsewhere component")
    end
  end

  describe "admin authorizations" do
    let(:own_user) { create(:user, :confirmed, organization:) }
    let(:other_user) { create(:user, :confirmed, organization: other_organization) }
    let!(:own_authorization) { create(:authorization, :granted, user: own_user, name: "user_extension") }
    let!(:other_authorization) { create(:authorization, :granted, user: other_user, name: "user_extension") }

    before do
      create(:awesome_config, organization:, var: "admins_available_authorizations", value: ["user_extension"])
    end

    it "destroys an authorization of a user of the current organization" do
      delete decidim_admin_decidim_awesome.admin_authorization_path(own_user, handler: "user_extension")

      expect(response).to have_http_status(:ok)
      expect(Decidim::Authorization).not_to exist(own_authorization.id)
    end

    it "does not show a user of another organization" do
      get decidim_admin_decidim_awesome.edit_admin_authorization_path(other_user, handler: "user_extension")

      expect(response).to have_http_status(:not_found)
    end

    it "does not destroy an authorization of a user of another organization" do
      delete decidim_admin_decidim_awesome.admin_authorization_path(other_user, handler: "user_extension")

      expect(response).to have_http_status(:not_found)

      expect(Decidim::Authorization).to exist(other_authorization.id)
    end
  end
end
