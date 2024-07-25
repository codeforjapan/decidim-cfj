# frozen_string_literal: true

require "pg_search"

Rails.application.config.to_prepare do
  ## define `PgSearch::Features::Bigram` to use pg_bigm extension
  module PgSearch
    module Features
      class Bigram < Feature
        def conditions
          if options[:threshold]
            Arel::Nodes::Grouping.new(
              similarity.gteq(options[:threshold])
            )
          else
            Arel::Nodes::Grouping.new(
              Arel::Nodes::InfixOperation.new(
                infix_operator,
                normalized_document,
                normalized_query_for_like
              )
            )
          end
        end

        def rank
          Arel::Nodes::Grouping.new(similarity)
        end

        private

        def similarity_function
          "bigm_similarity"
        end

        def infix_operator
          "like"
        end

        def similarity
          Arel::Nodes::NamedFunction.new(
            similarity_function,
            [
              normalized_query,
              normalized_document
            ]
          )
        end

        def normalized_document
          Arel::Nodes::Grouping.new(Arel.sql(normalize(document)))
        end

        def normalized_query_for_like
          sanitized_query = connection.quote(query)
          Arel.sql("likequery(#{normalize(sanitized_query)})")
        end

        def normalized_query
          sanitized_query = connection.quote(query)
          Arel.sql(normalize(sanitized_query))
        end
      end
    end
  end

  ## override `PgSearch::ScopeOptions::FEATURE_CLASSES`
  PgSearch::ScopeOptions::FEATURE_CLASSES = {
    dmetaphone: PgSearch::Features::DMetaphone,
    tsearch: PgSearch::Features::TSearch,
    trigram: PgSearch::Features::Trigram,
    bigram: PgSearch::Features::Bigram
  }.freeze
end
