# frozen_string_literal: true

module UploadedFileHelpers
  def uploaded_file_from_string(content, filename: "users.csv", type: "text/csv")
    Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: filename)
  end
end
