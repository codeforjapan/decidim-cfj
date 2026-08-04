# frozen_string_literal: true

require "rails_helper"

RSpec.describe OmniAuth::Logging do
  it "publishes only non-sensitive success metadata" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe("omniauth.auth.succeed") do |*args|
      events << args.last
    end

    app = Class.new do
      def call_app!(_env)
        [200, {}, []]
      end
    end
    app.prepend(described_class)

    auth = OmniAuth::AuthHash.new(
      provider: "cityos_dcp_login",
      uid: "personal-id",
      info: { email: "person@example.com" },
      credentials: { token: "bearer-secret", refresh_token: "refresh-secret" }
    )
    env = {
      "omniauth.auth" => auth,
      "action_dispatch.request_id" => "request-id"
    }

    app.new.call_app!(env)

    expect(events.last).to eq(provider: "cityos_dcp_login", request_id: "request-id")
    expect(events.last.to_s).not_to include("personal-id", "person@example.com", "bearer-secret", "refresh-secret")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  it "writes a sanitized success log" do
    allow(Rails.logger).to receive(:info)

    ActiveSupport::Notifications.instrument(
      "omniauth.auth.succeed",
      provider: "cityos_dcp_login\nforged",
      request_id: "request-id\nforged"
    )

    expect(Rails.logger).to have_received(:info).with(
      match(/result=success provider=cityos_dcp_loginforged .* request_id=request-idforged/)
    )
  end
end
