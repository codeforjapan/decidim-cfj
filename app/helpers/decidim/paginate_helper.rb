# frozen_string_literal: true

# Overide Decidim::PaginateHelper to backport https://github.com/decidim/decidim/pull/6986
# We should remove this file when upgrade Decidim 0.24.0.

module Decidim
  # Helper to paginate collections.
  module PaginateHelper
    # Displays pagination links for the given collection, setting the correct
    # theme. This mostly acts as a proxy for the underlying pagination engine.
    #
    # collection - a collection of elements that need to be paginated
    # paginate_params - a Hash with options to delegate to the pagination helper.
    def decidim_paginate(collection, paginate_params = {})
      paginate collection, theme: "decidim", params: paginate_params
    end
  end
end
