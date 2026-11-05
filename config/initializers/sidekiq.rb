# frozen_string_literal: true

require "sidekiq"

# Sidekiq's default error handler dumps the whole job when it raises,
# including arguments such as the raw tokens of Devise mails and the message of
# the exception stored by the retry. This one logs only job metadata known to
# be safe, plus the ActiveJob class and id to tie the entry to the ActiveJob
# logs. The exception message itself is still logged, as before.
module SidekiqErrorContextFilter
  def self.install(config)
    config.error_handlers.delete(Sidekiq.method(:default_error_handler))
    config.error_handlers << self unless config.error_handlers.include?(self)
  end

  def self.call(exception, context)
    Sidekiq.default_error_handler(exception, filter(context))
  end

  def self.filter(context)
    context = context.except(:jobstr)
    job = context[:job]
    return context unless job.is_a?(Hash)

    safe_job = job.slice("class", "wrapped", "jid", "queue", "retry_count", "error_class", "created_at", "enqueued_at")
    context.merge(job: safe_job.merge("args" => filter_args(job["args"])))
  end

  def self.filter_args(args)
    Array(args).map do |arg|
      arg.is_a?(Hash) ? arg.slice("job_class", "job_id").merge("arguments" => "[FILTERED]") : "[FILTERED]"
    end
  end
end

Sidekiq.configure_server { |config| SidekiqErrorContextFilter.install(config) }
