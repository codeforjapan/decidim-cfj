# frozen_string_literal: true

require "rails_helper"

describe HeicPreviewer do
  it "previews a heic image" do
    content_type = "image/heic"
    blob = create_file_blob(filename: "heic-image-file.heic", content_type: content_type)

    expect(blob).not_to be_nil
    expect(HeicPreviewer.accept?(blob)).to be_truthy # rubocop:disable RSpec/PredicateMatcher

    HeicPreviewer.new(blob).preview do |attachable|
      expect(attachable[:content_type]).to eq("image/png")
    end
  end
end
