# frozen_string_literal: true

# Sanitize user name rendering across presenters.
# - Tightens the name format validation to reject newlines as well.
# - Ensures UserPresenter#name and Log::UserPresenter#present_user_name
#   return sanitized output before being rendered as HTML-safe strings.

Rails.application.config.to_prepare do
  Decidim::UserBaseEntity # rubocop:disable Lint/Void
  Decidim::UserPresenter # rubocop:disable Lint/Void
  Decidim::Log::UserPresenter # rubocop:disable Lint/Void

  Decidim::UserBaseEntity.send(:remove_const, :REGEXP_NAME) if Decidim::UserBaseEntity.const_defined?(:REGEXP_NAME, false)
  Decidim::UserBaseEntity.const_set(:REGEXP_NAME, /\A(?!.*[<>?%&\^*#@()\[\]=+:;"{}\\|\n\r])/m)

  Decidim::UserBaseEntity.validators_on(:name).each do |validator|
    next unless validator.instance_of?(ActiveModel::Validations::FormatValidator)

    fixed_options = validator.options.dup
    fixed_options[:with] = Decidim::UserBaseEntity::REGEXP_NAME
    validator.instance_eval do
      @options = fixed_options.freeze
    end
  end

  module UserPresenterSanitizeName
    def name
      decidim_sanitize_translated(__getobj__.name)
    end
  end

  module LogUserPresenterSanitizeName
    def present_user_name
      decidim_sanitize_translated(extra["name"]).html_safe
    end
  end

  Decidim::UserPresenter.include(Decidim::SanitizeHelper)
  Decidim::UserPresenter.prepend(UserPresenterSanitizeName)

  Decidim::Log::UserPresenter.include(Decidim::SanitizeHelper)
  Decidim::Log::UserPresenter.prepend(LogUserPresenterSanitizeName)
end
