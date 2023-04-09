# frozen_string_literal: true

Rails.application.config.xray = {
  name: "decidim-cfj",
  patch: [:net_http, :aws_sdk],
  active_record: true,
  context_missing: "LOG_ERROR"
}
