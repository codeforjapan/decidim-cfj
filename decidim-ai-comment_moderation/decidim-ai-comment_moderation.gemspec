# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/ai/comment_moderation/version"

Gem::Specification.new do |spec|
  spec.name = "decidim-ai-comment_moderation"
  spec.version = Decidim::Ai::CommentModeration::VERSION
  spec.authors = ["Code for Japan"]
  spec.email = ["info@code4japan.org"]
  spec.homepage = "https://github.com/codeforjapan/decidim-cfj"
  spec.summary = "AI-powered comment moderation for Decidim"
  spec.description = "AI-powered comment moderation module for Decidim using OpenAI"
  spec.license = "AGPL-3.0"
  spec.required_ruby_version = ">= 3.0.6"

  spec.files = Dir[
    "{app,config,db,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  spec.add_dependency "decidim-comments", "~> 0.29.2"
  spec.add_dependency "decidim-core", "~> 0.29.2"
  spec.add_dependency "ruby-openai", "~> 6.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end
