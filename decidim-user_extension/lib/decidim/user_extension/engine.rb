module Decidim
  module UserExtension
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::UserExtension
    end
  end
end
