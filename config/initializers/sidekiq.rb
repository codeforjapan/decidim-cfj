# frozen_string_literal: true

require "sidekiq"

# Sidekiq's default error handler dumps the whole job when it raises,
# including arguments such as the raw tokens of Devise mails. This one logs the
# same, with the arguments left out but the ActiveJob class and id kept to tie
# the entry to the ActiveJob logs.
module SidekiqErrorContextFilter
  FILTERED = "[FILTERED]"

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

    context.merge(job: job.merge("args" => filter_args(job["args"])))
  end

  def self.filter_args(args)
    Array(args).map do |arg|
      arg.is_a?(Hash) ? arg.slice("job_class", "job_id").merge("arguments" => FILTERED) : FILTERED
    end
  end
end

Sidekiq.configure_server { |config| SidekiqErrorContextFilter.install(config) }
