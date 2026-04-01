# frozen_string_literal: true

module Decidim
  module Cfj
    module TaxonomyFlattenConstants
      # Intermediate level prefix patterns used by the category migration tool.
      # "参加スペース:" for assemblies, "参加型プロセス:" for participatory processes, etc.
      INTERMEDIATE_PREFIXES = /\A(参加スペース|参加型プロセス|Assembly|Participatory process|Conference|Initiative): /
    end
  end
end
