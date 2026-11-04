# frozen_string_literal: true

# This migration comes from decidim_assemblies (originally 20190215093700)
# This file has been modified by `decidim upgrade:migrations` task on 2026-09-11 08:07:31 UTC
class ResetNegativeChildrenCountCounters < ActiveRecord::Migration[5.2]
  class Assembly < ApplicationRecord
    self.table_name = :decidim_assemblies
  end

  def change
    ids = Assembly.unscoped.where("children_count < 0").pluck(:id)
    ids.each { |id| Assembly.unscoped.reset_counters(id, :children_count) }
  end
end
