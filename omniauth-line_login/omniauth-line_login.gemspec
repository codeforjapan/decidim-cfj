# frozen_string_literal: true

require_relative 'lib/omniauth/line_login/version'

Gem::Specification.new do |spec|
  spec.name = 'omniauth-line_login'
  spec.version = OmniAuth::LineLogin::VERSION
  spec.authors = ['takahashim']
  spec.email = ['takahashimm@gmail.com']

  spec.summary = 'Unofficial OmniAuth Strategy for LINE Login'
  spec.description = 'Unofficial OmniAuth Strategy for LINE Login'
  spec.homepage = 'https://github.com/takahashim/omniauth-line_login'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['homepage_uri'] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'omniauth-oauth2'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
