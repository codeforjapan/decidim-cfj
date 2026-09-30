# frozen_string_literal: true

namespace :decidim_awesome do
  desc "Enable mobile menu feature in database"
  task enable_mobile_menu: :environment do
    Decidim::Organization.find_each do |org|
      puts "Processing organization: #{org.name}"

      # Enable menu feature
      menu_config = Decidim::DecidimAwesome::AwesomeConfig.find_or_initialize_by(
        organization: org,
        var: "menu"
      )
      menu_config.value = []
      menu_config.save!
      puts "  ✓ Menu feature enabled"

      # Enable mobile_menu feature
      mobile_menu_config = Decidim::DecidimAwesome::AwesomeConfig.find_or_initialize_by(
        organization: org,
        var: "mobile_menu"
      )
      mobile_menu_config.value = []
      mobile_menu_config.save!
      puts "  ✓ Mobile menu feature enabled"
    end

    puts "\nDone! Please restart the application:"
    puts "  docker-compose restart web"
  end

  desc "Copy main menu items to mobile menu"
  task copy_menu_to_mobile: :environment do
    Decidim::Organization.find_each do |org|
      puts "Processing organization: #{org.name}"

      # This will be implemented once we confirm the correct model name
      puts "  Please use the admin interface to add menu items"
      puts "  URL: /admin/decidim_awesome/menus/mobile_menu/hacks"
    end
  end
end
