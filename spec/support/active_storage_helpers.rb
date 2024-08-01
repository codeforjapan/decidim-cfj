# frozen_string_literal: true

module ActiveStorageHelpers
  # ported from https://github.com/rails/rails/blob/4a17b26c6850dd0892dc0b58a6a3f1cce3169593/activestorage/test/test_helper.rb#L52
  def create_file_blob(filename: "image.jpg", content_type: "image/jpeg", metadata: nil)
    ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename:, content_type:, metadata:
  end
end
