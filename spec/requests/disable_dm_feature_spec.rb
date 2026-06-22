# frozen_string_literal: true

require "rails_helper"

# Verifies that the Decidim DM (private messaging / conversations) feature
# is disabled at the entry-point level: routes redirect to root, the
# Decidim::User#accepts_conversation? predicate always returns false, and
# the ConversationMailer never delivers anything.
RSpec.describe "Disable DM feature" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:other_user) { create(:user, :confirmed, organization:) }

  before { host! organization.host }

  describe "routes" do
    before { sign_in user, scope: :user }

    it "redirects /conversations to /" do
      get "/conversations"
      expect(response).to redirect_to("/")
    end

    it "redirects /conversations/new to /" do
      get "/conversations/new"
      expect(response).to redirect_to("/")
    end

    it "redirects /profiles/:nickname/conversations to /" do
      get "/profiles/#{user.nickname}/conversations"
      expect(response).to redirect_to("/")
    end

    it "redirects POST /conversations to /" do
      post "/conversations", params: { conversation: { body: "hi", recipient_id: other_user.id } }
      expect(response).to redirect_to("/")
    end

    it "redirects PUT /conversations/:id to / at the routing layer" do
      # Allow direct messages on both participants so that on main (without the
      # disable-dm-feature override) the Decidim conversations controller passes
      # its permission check and reaches the action. That way this spec fails
      # on main with a 200 response, ensuring the assertion below is meaningful.
      user.update!(direct_message_types: "all")
      other_user.update!(direct_message_types: "all")
      conversation = create(:conversation, originator: user, interlocutors: [other_user], user:, body: "hi")
      put "/conversations/#{conversation.id}", params: { message: { body: "reply" } }, xhr: true
      expect(response).to redirect_to("/")
      # Rails routing redirect() with status: 301 is what we configured;
      # controller-level redirects use 302. Asserting 301 guarantees the
      # request never reached the Decidim controller.
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "admin officializations page" do
    let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

    before { sign_in admin_user, scope: :user }

    it "does not render the contact (new conversation) icon link" do
      get "/admin/users"
      expect(response.body).not_to include("current_or_new_conversation")
      expect(response.body).not_to match(/href="[^"]*conversation[^"]*"/)
    end
  end

  describe "Decidim::User#accepts_conversation?" do
    it "always returns false regardless of direct_message_types" do
      user.update!(direct_message_types: "all")
      expect(user.accepts_conversation?(other_user)).to be(false)
    end
  end

  describe "Decidim::UserPresenter#can_be_contacted?" do
    it "always returns false so that cells/views relying on it hide the contact link" do
      user.update!(direct_message_types: "all")
      expect(Decidim::UserPresenter.new(user).can_be_contacted?).to be(false)
    end
  end

  describe Decidim::Admin::Moderations::ReportsHelper, type: :helper do
    let(:component) { create(:dummy_component, organization:) }
    let(:reportable) { create(:dummy_resource, component:, author: user) }

    it "renders the user author name without a conversation link" do
      output = helper.reportable_author_name(reportable)
      expect(output).to include(user.name)
      expect(output).not_to include("<a ")
      expect(output).not_to include("mail-send-line")
    end
  end

  describe "notifications settings page" do
    before { sign_in user, scope: :user }

    it "does not render the allow_public_contact toggle" do
      get "/notifications_settings"
      expect(response.body).not_to include("allow_public_contact")
    end
  end

  describe "footer" do
    before { sign_in user, scope: :user }

    it "does not include a link to /conversations" do
      get "/"
      expect(response.body).not_to include("/conversations")
    end
  end

  describe "Decidim::Exporters::OpenDataUserSerializer" do
    subject(:serialized) { Decidim::Exporters::OpenDataUserSerializer.new(user).serialize }

    it "forces direct_messages_enabled to false even when the user allows DMs" do
      user.update!(direct_message_types: "all")
      expect(serialized[:direct_messages_enabled]).to be(false)
    end

    it "keeps the direct_messages_enabled key so the Open Data schema is preserved" do
      expect(serialized).to have_key(:direct_messages_enabled)
    end
  end

  describe "Decidim::Messaging::ConversationMailer" do
    let(:conversation) do
      create(:conversation, originator: user, interlocutors: [other_user], user:, body: "hi")
    end

    it "does not deliver new_conversation mails" do
      mail = Decidim::Messaging::ConversationMailer.new_conversation(user, other_user, conversation)
      expect(mail.perform_deliveries).to be(false)
    end

    it "does not enqueue a delivery when deliver_now is called" do
      expect do
        Decidim::Messaging::ConversationMailer
          .new_conversation(user, other_user, conversation)
          .deliver_now
      end.not_to(change { ActionMailer::Base.deliveries.size })
    end

    it "does not deliver new_message mails either (prepend covers all actions)" do
      message = conversation.messages.first
      mail = Decidim::Messaging::ConversationMailer.new_message(user, other_user, conversation, message)
      expect(mail.perform_deliveries).to be(false)
    end
  end
end
