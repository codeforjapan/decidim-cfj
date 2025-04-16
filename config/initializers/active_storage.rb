# frozen_string_literal: true

require Rails.root.join("app/previewers/heic_previewer")

Rails.application.configure do
  config.active_storage.previewers << HeicPreviewer
  config.active_storage.variable_content_types << "image/heic"
  config.active_storage.variable_content_types << "image/heif"
end
