# frozen_string_literal: true

# This monkey patch force the output of `Faker::Internet.slug()` to be in English.
module FakerInternetEnglishExtension
  def slug(words: nil, glue: nil)
    super
    with_locale(:en) do
      glue ||= sample(%w(- _))
      (words || Faker::Lorem.words(number: 2).join(" ")).delete(",.").gsub(" ", glue).downcase
    end
  end
end

Faker::Internet.singleton_class.prepend(FakerInternetEnglishExtension)
