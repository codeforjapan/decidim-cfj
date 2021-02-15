# frozen_string_literal: true

module Decidim
  module UserExtension
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
    end
  end
end
