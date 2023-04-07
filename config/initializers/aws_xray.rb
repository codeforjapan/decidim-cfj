Rails.application.config.xray = {
  name: 'decidim-cfj',
  patch: %I[net_http aws_sdk],
  active_record: true,
  context_missing: 'LOG_ERROR'
}
