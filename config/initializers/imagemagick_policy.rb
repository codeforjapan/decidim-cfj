# frozen_string_literal: true

# Make every ImageMagick process spawned by MiniMagick also read config/imagemagick/policy.xml.
# The environment variable is inherited by child processes (web and Sidekiq alike).
policy_dir = Rails.root.join("config/imagemagick").to_s
paths = ENV.fetch("MAGICK_CONFIGURE_PATH", "").split(File::PATH_SEPARATOR)
ENV["MAGICK_CONFIGURE_PATH"] = [policy_dir, *paths.excluding(policy_dir)].join(File::PATH_SEPARATOR)
