# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Records looked up within the current organization" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:process) { create(:participatory_process, :with_steps, :published, organization:) }
  let(:component) do
    create(
      :proposal_component,
      :published,
      participatory_space: process,
      settings: { amendments_enabled: true },
      step_settings: { process.active_step.id => { amendment_creation_enabled: true, amendment_reaction_enabled: true } }
    )
  end
  let(:proposal) { create(:proposal, component:, users: [user]) }

  let(:other_organization) { create(:organization) }
  let(:other_process) { create(:participatory_process, :with_steps, :published, organization: other_organization) }
  let(:other_component) { create(:proposal_component, :published, participatory_space: other_process) }
  let(:other_proposal) { create(:proposal, component: other_component) }

  before do
    host! organization.host
    sign_in user, scope: :user
  end

  describe "comments" do
    let!(:other_comment) { create(:comment, commentable: other_proposal, body: { en: "Original body" }) }

    # Make the signed-in user the author, so the permission checks alone
    # would let the request through.
    before { other_comment.update_columns(decidim_author_id: user.id) } # rubocop:disable Rails/SkipsModelValidations

    it "does not list the comments of a resource of another organization" do
      get "/comments", params: { commentable_gid: other_proposal.to_signed_global_id.to_s }, xhr: true

      expect(response).to have_http_status(:not_found)
    end

    it "does not update a comment of another organization" do
      put "/comments/#{other_comment.id}", params: { comment: { body: "Updated body" } }, xhr: true

      expect(response).to have_http_status(:not_found)
      expect(other_comment.reload.body["en"]).to eq("Original body")
    end

    it "does not delete a comment of another organization" do
      delete "/comments/#{other_comment.id}", xhr: true

      expect(response).to have_http_status(:not_found)
      expect(other_comment.reload).not_to be_deleted
    end

    it "does not vote on a comment of another organization" do
      post "/comments/#{other_comment.id}/votes", params: { weight: 1 }, xhr: true

      expect(response).to have_http_status(:not_found)
      expect(other_comment.up_votes.count).to eq(0)
    end

    context "when the comment belongs to the organization" do
      let!(:comment) { create(:comment, commentable: proposal, author: user, body: { en: "Original body" }) }

      it "lists the comments of the resource" do
        get "/comments", params: { commentable_gid: proposal.to_signed_global_id.to_s }, xhr: true

        expect(response).to have_http_status(:ok)
      end

      it "updates the comment" do
        put "/comments/#{comment.id}", params: { comment: { body: "Updated body" } }, xhr: true

        expect(response).to have_http_status(:ok)
        expect(comment.reload.body["en"]).to eq("Updated body")
      end

      it "deletes the comment" do
        delete "/comments/#{comment.id}", xhr: true

        expect(response).to have_http_status(:ok)
        expect(comment.reload).to be_deleted
      end

      it "votes on the comment" do
        post "/comments/#{comment.id}/votes", params: { weight: 1 }, xhr: true

        expect(response).to have_http_status(:ok)
        expect(comment.up_votes.count).to eq(1)
      end
    end
  end

  describe "amendments" do
    let(:other_emendation) { create(:proposal, component: other_component) }
    let!(:other_amendment) { create(:amendment, amendable: other_proposal, emendation: other_emendation, state: "evaluating") }

    let(:emendation) { create(:proposal, component:) }
    let!(:amendment) { create(:amendment, amendable: proposal, emendation:, state: "evaluating") }

    it "does not start an amendment for a resource of another organization" do
      get "/amends/new", params: { amendable_gid: other_proposal.to_sgid.to_s }

      expect(response).to have_http_status(:not_found)
    end

    it "does not review an amendment of another organization" do
      get "/amends/#{other_amendment.id}/review"

      expect(response).to have_http_status(:not_found)
    end

    it "does not take a local resource as the amendable of an amendment of another organization" do
      patch "/amends/#{other_amendment.id}/reject", params: { amendable_gid: proposal.to_sgid.to_s }

      expect(response).to have_http_status(:not_found)
      expect(other_amendment.reload.state).to eq("evaluating")
    end

    context "with nested amendment params" do
      let(:emendation_params) { { title: "Another title for this emendation", body: "Another body for this emendation, long enough" } }

      it "creates the amendment for the resource given at the top level" do
        post "/amends", params: {
          amendable_gid: proposal.to_sgid.to_s,
          amendment: { amendable_gid: other_proposal.to_sgid.to_s, emendation_params: }
        }

        expect(proposal.amendments.where(state: "draft")).to exist
        expect(other_proposal.amendments.where(state: "draft")).not_to exist
      end

      it "does not accept an amendment of another organization given in the nested params" do
        patch "/amends/#{amendment.id}/accept", params: { amendment: { id: other_amendment.id, emendation_params: } }

        expect(other_amendment.reload.state).to eq("evaluating")
      end
    end

    it "starts an amendment for a resource of the organization" do
      get "/amends/new", params: { amendable_gid: proposal.to_sgid.to_s }

      expect(response).to have_http_status(:ok)
    end

    it "reviews an amendment of the organization", versioning: true do
      get "/amends/#{amendment.id}/review"

      expect(response).to have_http_status(:ok)
    end

    it "rejects an amendment of the organization" do
      patch "/amends/#{amendment.id}/reject"

      expect(amendment.reload.state).to eq("rejected")
    end
  end

  describe "coauthor invitations" do
    let(:other_organization_user) { create(:user, :confirmed, organization: other_organization) }
    let(:path) { Decidim::EngineRouter.main_proxy(component).proposal_invite_coauthors_path(proposal_id: proposal.id) }

    it "does not invite a user of another organization" do
      post path, params: { id: other_organization_user.id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
