# frozen_string_literal: true

require "test_helper"

class HeicPreviewerTest < ActiveSupport::TestCase
  include ActiveStorageBlob

  CONTENT_TYPE = "image/heic"

  test "it previews a heic image" do
    skip "it does not run on CI due to missing support for HEIC" if ENV["CI"] == "true"

    blob = create_file_blob(filename: "heic-image-file.heic", content_type: CONTENT_TYPE)

    assert_not_nil blob
    assert HeicPreviewer.accept?(blob)

    HeicPreviewer.new(blob).preview({}) do |attachable|
      assert_equal "image/png", attachable[:content_type]
    end
  end
end
