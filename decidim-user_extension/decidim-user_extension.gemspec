# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.required_ruby_version = ">= 2.7.0"
end

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/user_extension/version"

Gem::Specification.new do |spec|
  spec.name = "decidim-user_extension"
  spec.version = Decidim::UserExtension::VERSION
  spec.authors = ["takahashim"]
  spec.email = ["takahashimm@gmail.com"]
  spec.homepage = "https://github.com/codeforjapan/decidim-cfj"
  spec.summary = "A exntesional attributes component for decidim's User model."
  spec.description = "A exntesional attributes component for decidim's User model."
  spec.license = "AGPL-3.0"

  spec.files = Dir[
    "{app,config,db,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  spec.add_dependency "decidim-admin"
  spec.add_dependency "decidim-core"
  spec.add_dependency "rails", "~> 5.2.4", ">= 5.2.4.4"

  spec.add_development_dependency "decidim-dev"
end
