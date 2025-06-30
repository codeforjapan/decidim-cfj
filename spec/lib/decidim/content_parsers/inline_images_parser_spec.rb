# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../lib/decidim/content_parsers/inline_images_parser"

module Decidim
  module ContentParsers
    describe InlineImagesParser do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, organization:) }
      let(:context) { { user: } }

      describe "#rewrite with Global ID path override" do
        let(:base64_image) { "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAHGartKiAAAAABJRU5ErkJggg==" }
        let(:content) { %(<p>Some text</p><img src="#{base64_image}"><p>More text</p>) }

        subject { described_class.new(content, context).rewrite }

        it "creates EditorImage and uses Global ID instead of signed URL" do
          expect { subject }.to change(EditorImage, :count).by(1)

          editor_image = EditorImage.last

          # Check that the subject contains Global ID instead of signed URL
          expect(subject).to include("img src=\"#{editor_image.file.blob.to_global_id}\"")
          expect(subject).not_to match(/amazonaws\.com/)
          expect(subject).not_to match(/signature=/)
        end

        it "preserves other HTML content" do
          expect(subject).to include("<p>Some text</p>")
          expect(subject).to include("<p>More text</p>")
        end

        context "when no user is provided" do
          let(:context) { {} }

          it "raises an error because organization is required" do
            expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
          end
        end

        context "with multiple images" do
          let(:content) do
            <<~HTML
              <p>First image:</p>
              <img src="#{base64_image}">
              <p>Second image:</p>
              <img src="#{base64_image}">
            HTML
          end

          it "converts all images to Global IDs" do
            expect { subject }.to change(EditorImage, :count).by(2)

            EditorImage.last(2).each do |editor_image|
              expect(subject).to include("img src=\"#{editor_image.file.blob.to_global_id}\"")
            end
          end
        end
      end
    end
  end
end
