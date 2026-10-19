# frozen_string_literal: true

require "rails_helper"

RSpec.describe "sidekiq initializer" do
  let(:token) { "secret-token-value" }

  # Sidekiq.configure_server only runs in a Sidekiq process, so the installation
  # is checked on the handlers it would be given there.
  describe "SidekiqErrorContextFilter.install" do
    let!(:original_handlers) { Sidekiq.error_handlers.dup }

    before do
      Sidekiq.error_handlers.replace([Sidekiq.method(:default_error_handler)])
      SidekiqErrorContextFilter.install(Sidekiq)
      SidekiqErrorContextFilter.install(Sidekiq)
    end

    after { Sidekiq.error_handlers.replace(original_handlers) }

    it "replaces the default error handler once" do
      expect(Sidekiq.error_handlers).to eq([SidekiqErrorContextFilter])
    end
  end

  describe "SidekiqErrorContextFilter.call" do
    let(:output) { StringIO.new }
    let(:job) do
      {
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "wrapped" => "ActionMailer::MailDeliveryJob",
        "jid" => "abc",
        "args" => [{ "job_class" => "ActionMailer::MailDeliveryJob", "job_id" => "job-1", "arguments" => [token] }]
      }
    end

    before do
      allow(Sidekiq).to receive(:logger).and_return(Logger.new(output))
      SidekiqErrorContextFilter.call(StandardError.new("boom"), { context: "Job raised exception", job:, jobstr: Sidekiq.dump_json(job) })
    end

    it "logs the job without its arguments" do
      expect(output.string).not_to include(token)
      expect(output.string).to include("boom", "abc")
    end

    it "keeps the ActiveJob class and id" do
      expect(output.string).to include("ActionMailer::MailDeliveryJob", "job-1")
    end
  end
end
