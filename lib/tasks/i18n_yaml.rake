# frozen_string_literal: true

def deep_keys(hash, prefix = "")
  hash.flat_map do |key, value|
    full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
    value.is_a?(Hash) ? deep_keys(value, full_key) : full_key
  end
end

namespace :i18n_yaml do
  desc "dump all locale data for some locale"
  task dump_all: :environment do
    locale = :ja
    all_translations = I18n.t(".", locale: locale, default: {}).deep_merge({})
    keys = deep_keys(all_translations)
    buf = []
    I18n.with_locale(locale) do
      keys.each do |key|
        # skip faker.*
        next if key.start_with?("faker.")

        buf << "#{key}: #{I18n.t(key)}"
      rescue StandardError => e
        warn "ERROR: #{key}, #{e.message}"
      end
    end

    puts buf
  end
end
