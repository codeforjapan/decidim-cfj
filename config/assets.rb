# frozen_string_literal: true

# This file is located at `config/assets.rb` of your module.

# Define the base path of your module. Please note that `Rails.root` may not be
# used because we are not inside the Rails environment when this file is loaded.
# base_path = File.expand_path("..", __dir__)

# If you want to import some extra SCSS files in the Decidim main SCSS file
# without adding any extra stylesheet inclusion tags, you can use the following
# method to register the stylesheet import for the main application. This would
# include an SCSS file at `app/packs/stylesheets/your_app_extensions.scss` into
# the Decidim's main SCSS file.
# Decidim::Webpacker.register_stylesheet_import("stylesheets/your_app_extensions")

# If you want to do the same but include the SCSS file for the admin panel's
# main SCSS file, you can use the following method.
# Decidim::Webpacker.register_stylesheet_import("stylesheets/your_app_admin_extensions", group: :admin)
