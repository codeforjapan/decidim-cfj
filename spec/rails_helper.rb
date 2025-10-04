# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../config/environment", __dir__)
# require File.expand_path("../../config/environment", __FILE__)

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

require "decidim/dev"
Decidim::Dev.dummy_app_path = File.expand_path(File.join(__dir__, ".."))
require "decidim/dev/test/base_spec_helper"

# Add additional requires below this line. Rails is not loaded until this point!

# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob("spec/support/**/*.rb").each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include ActiveStorageHelpers

  # Override organization factory to use correct locales
  config.before(:suite) do
    FactoryBot.modify do
      factory :organization, class: "Decidim::Organization" do
        available_locales { [:ja, :en] }
        default_locale { :ja }
      end
    end
  end

  config.append_before do
    ## XXX: Override CSP settings
    # cf. https://github.com/decidim/decidim/blob/a1768d7c19c0c80b19f5a1be6d888668f121a6be/decidim-dev/lib/decidim/dev/test/spec_helper.rb#L43-L46
    Decidim.config.content_security_policies_extra = {
      "default-src" => ["*"],
      "img-src" => ["*"],
      "media-src" => ["*"],
      "script-src" => ["*"],
      "style-src" => ["*", "fonts.googleapis.com"],
      "font-src" => ["*"],
      "frame-src" => ["*"],
      "connect-src" => ["*"]
    }
  end
end
