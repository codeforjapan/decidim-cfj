# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe NotificationsDigestMailer do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, :admin, organization:, locale: "ja", notifications_sending_frequency: "real_time") }
    let(:decidim) { Decidim::Core::Engine.routes.url_helpers }

    describe "#notifications_digest" do
      let(:mail) { described_class.digest_mail(user, notification_ids) }
      let(:notification_ids) { [notification.id] }
      let(:resource) { create(:proposal, component: create(:component, manifest_name: "proposals")) }
      let(:notification) { create(:notification, user:, resource:) }

      describe "email body" do
        it "includes the real-time header translation" do
          expect(email_body(mail)).to include('<p class="email-header"> リアルタイム </p>')
        end

        it "includes the real-time intro translation" do
          expect(email_body(mail)).to include("あなたがフォローしているアクティビティに基づいた通知です:")
        end
      end
    end
  end
end
