# frozen_string_literal: true

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
  spec.required_ruby_version = ">= 3.0.2"

  spec.files = Dir[
    "{app,config,db,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  spec.add_dependency "decidim-admin"
  spec.add_dependency "decidim-core"
  spec.add_dependency "rails"

  spec.add_development_dependency "decidim-dev"
end
