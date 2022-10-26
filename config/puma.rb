# frozen_string_literal: true

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch("PORT", 3000)

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV", "development")

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

class SlackChatMessenger
  def self.notify(channel:, message:)
    client = Slack::Web::Client.new
    client.chat_postMessage(channel: channel, text: message, as_user: true)
  end
end

before_fork do
  PumaWorkerKiller.config do |config|
    config.ram = 2048
    config.frequency = 5
    config.percent_usage = 0.9
    config.rolling_restart_frequency = 24 * 60 * 60
    config.reaper_status_logs = true
    config.pre_term = lambda do |worker|
      SlackChatMessenger.notify(channel: ENV['SLACK_MESSAGE_CHANNEL'], message: "[#{Rails.env}] Worker #{worker.index}(#{worker.pid}) being killed") # rubocop:disable Style/StringLiterals
      puts "Worker #{worker.index}(#{worker.pid}) being killed"
    end
  end
  PumaWorkerKiller.start
end

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked webserver processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
workers ENV.fetch("WEB_CONCURRENCY", 2)

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
# preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart
