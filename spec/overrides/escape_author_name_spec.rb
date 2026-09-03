# frozen_string_literal: true

require "rails_helper"

# Covers app/overrides/decidim/proposals/admin/proposals/show/escape_author_name.html.erb.deface.
#
# Deface only logs a warning when a selector stops matching, so an upstream
# change to the view would drop the override without failing anything.
RSpec.describe "Proposal admin show author name override" do
  let(:virtual_path) { "decidim/proposals/admin/proposals/show" }

  let(:source) do
    File.read(
      File.join(
        Gem.loaded_specs["decidim-proposals"].gem_dir,
        "app/views/#{virtual_path}.html.erb"
      )
    )
  end

  let(:result) { Deface::Override.apply(source, { virtual_path: }, false) }

  it "is registered for the view" do
    expect(Deface::Override.all[virtual_path.to_sym].keys).to include("escape_author_name")
  end

  it "escapes the author name" do
    expect(result).to include("decidim_html_escape(presented_author.name)")
  end

  it "leaves no unescaped author name behind" do
    expect(result.scan(/(?<!decidim_html_escape\()presented_author\.name/)).to be_empty
  end
end
