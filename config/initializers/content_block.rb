# frozen_string_literal: true

Decidim.content_blocks.register(:homepage, :last_comment) do |content_block|
  content_block.cell = "decidim/content_blocks/last_comment"
  content_block.public_name_key = "decidim.content_blocks.last_comment.name"
  content_block.default!
end
