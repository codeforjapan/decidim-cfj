# frozen_string_literal: true

# This monkey patch force the output of `Faker::Internet.slug()` to be in English.
module FakerInternetEnglishExtension
  if Gem::Version.create(Faker::VERSION) < Gem::Version.create('2.0.0')

    def slug(words = nil, glue = nil)
      with_locale(:en) do
        glue ||= sample(%w[- _])
        (words || Faker::Lorem.words(2).join(' ')).delete(',.').gsub(' ', glue).downcase
      end
    end

  else

    def slug(legacy_words = NOT_GIVEN, legacy_glue = NOT_GIVEN, words: nil, glue: nil)
      super
      with_locale(:en) do
        glue ||= sample(%w[- _])
        (words || Faker::Lorem.words(number: 2).join(' ')).delete(',.').gsub(' ', glue).downcase
      end
    end

  end
end

Faker::Internet.singleton_class.prepend(FakerInternetEnglishExtension)
