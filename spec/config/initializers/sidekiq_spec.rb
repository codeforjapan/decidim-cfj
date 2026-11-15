# frozen_string_literal: true

require "rails_helper"

RSpec.describe "sidekiq initializer" do
  let(:token) { "secret-token-value" }
  let(:other_handler) { ->(_exception, _context, _config) {} }
  let(:sidekiq_config) { Sidekiq.default_configuration }
  let!(:original_handlers) { sidekiq_config.error_handlers.dup }

  after { sidekiq_config.error_handlers.replace(original_handlers) }

  describe "SidekiqErrorContextFilter.install" do
    before do
      sidekiq_config.error_handlers.replace([other_handler, Sidekiq::Config::ERROR_HANDLER])
      SidekiqErrorContextFilter.install(sidekiq_config)
      SidekiqErrorContextFilter.install(sidekiq_config)
    end

    it "replaces only the default error handler, once" do
      expect(sidekiq_config.error_handlers).to eq([other_handler, SidekiqErrorContextFilter])
    end
  end

  # Sidekiq.configure_server only yields in a Sidekiq process, which
  # Sidekiq.server? tells from Sidekiq::CLI being defined.
  describe "booting a Sidekiq server" do
    before do
      sidekiq_config.error_handlers.replace([Sidekiq::Config::ERROR_HANDLER])
      allow(Sidekiq).to receive(:server?).and_return(true)
      load Rails.root.join("config/initializers/sidekiq.rb")
    end

    it "installs the filter in place of the default error handler" do
      expect(sidekiq_config.error_handlers).to eq([SidekiqErrorContextFilter])
    end
  end

  describe "SidekiqErrorContextFilter.call" do
    let(:output) { StringIO.new }
    let(:args) do
      [{
        "job_class" => "ActionMailer::MailDeliveryJob",
        "job_id" => "job-1",
        "arguments" => ["Decidim::DecidimDeviseMailer", "invitation_instructions", { "args" => [{ "token" => token }, [token]] }]
      }]
    end
    let(:job) do
      {
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "wrapped" => "ActionMailer::MailDeliveryJob",
        "jid" => "abc",
        "queue" => "mailers",
        "args" => args,
        "retry_count" => 2,
        "error_class" => "RuntimeError",
        "error_message" => "Invalid token: #{token}",
        "error_backtrace" => "compressed #{token}",
        "custom_tag" => token
      }
    end

    before do
      allow(sidekiq_config).to receive(:logger).and_return(Logger.new(output))
      SidekiqErrorContextFilter.call(StandardError.new("boom"), { context: "Job raised exception", job:, jobstr: Sidekiq.dump_json(job) })
    end

    it "logs neither the arguments nor the stored error message" do
      expect(output.string).not_to include(token)
      expect(output.string).to include("boom")
    end

    it "keeps the job metadata and the ActiveJob class and id" do
      expect(output.string).to include("abc", "mailers", "RuntimeError", "\"retry_count\":2", "ActionMailer::MailDeliveryJob", "job-1")
    end

    context "with a plain Sidekiq job" do
      let(:args) { [token, { "nested" => [token] }] }

      it "does not log its arguments" do
        expect(output.string).not_to include(token)
      end
    end
  end
end
