# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Blogs
    module Admin
      describe PostForm, type: :form do
        let(:organization) { create(:organization) }
        let(:user) { create(:user, :admin, organization:) }
        let(:participatory_process) { create(:participatory_process, organization:) }
        let(:component) { create(:component, manifest_name: :blogs, participatory_space: participatory_process) }
        let(:current_component) { component }
        let(:current_user) { user }

        let(:editor_image) { create(:editor_image, author: user, organization:) }
        let(:blob) { editor_image.file.blob }
        let(:s3_url) { "https://test-bucket.s3.amazonaws.com/#{blob.key}?signature=abc123" }
        let(:rails_url) { "/rails/active_storage/blobs/redirect/encoded_key/test-image.jpg" }
        let(:global_id) { blob.to_global_id.to_s }

        let(:body_with_s3_url) do
          {
            "ja" => "<p>テスト内容 <img src=\"#{s3_url}\" alt=\"画像\"> 続き</p>",
            "en" => "<p>Test content <img src=\"#{s3_url}\" alt=\"image\"> more</p>"
          }
        end

        let(:body_with_rails_url) do
          {
            "ja" => "<p>テスト内容 <img src=\"#{rails_url}\" alt=\"画像\"> 続き</p>",
            "en" => "<p>Test content <img src=\"#{rails_url}\" alt=\"image\"> more</p>"
          }
        end

        let(:body_with_global_id) do
          {
            "ja" => "<p>テスト内容 <img src=\"#{global_id}\" alt=\"画像\"> 続き</p>",
            "en" => "<p>Test content <img src=\"#{global_id}\" alt=\"image\"> more</p>"
          }
        end

        let(:params) do
          {
            title: { "ja" => "テストタイトル", "en" => "Test Title" },
            body: body_with_s3_url,
            decidim_author_id: user.id
          }
        end

        subject do
          described_class.from_params(params).with_context(
            current_user: user,
            current_organization: organization,
            current_component: component
          )
        end

        before do
          # Mock UrlConverter to return Global ID for test URLs
          allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
            .and_return(global_id)

          allow(Decidim::Cfj::UrlConverter).to receive(:rails_url_to_global_id)
            .and_return(global_id)
        end

        describe "URL conversion in rich text content" do
          context "when body contains S3 URLs" do
            it "converts S3 URLs to Global IDs before validation" do
              form = subject
              expect(form).to be_valid

              # Check that S3 URLs were converted to Global IDs
              expect(form.body["ja"]).to include(global_id)
              expect(form.body["ja"]).not_to include(s3_url)
              expect(form.body["en"]).to include(global_id)
              expect(form.body["en"]).not_to include(s3_url)
            end
          end

          context "when body contains Rails blob URLs" do
            let(:params) do
              {
                title: { "ja" => "テストタイトル", "en" => "Test Title" },
                body: body_with_rails_url,
                decidim_author_id: user.id
              }
            end

            it "converts Rails URLs to Global IDs before validation" do
              form = subject
              expect(form).to be_valid

              # Check that Rails URLs were converted to Global IDs
              expect(form.body["ja"]).to include(global_id)
              expect(form.body["ja"]).not_to include(rails_url)
              expect(form.body["en"]).to include(global_id)
              expect(form.body["en"]).not_to include(rails_url)
            end
          end

          context "when body already contains Global IDs" do
            let(:params) do
              {
                title: { "ja" => "テストタイトル", "en" => "Test Title" },
                body: body_with_global_id,
                decidim_author_id: user.id
              }
            end

            it "leaves Global IDs unchanged" do
              form = subject
              expect(form).to be_valid

              # Global IDs should remain unchanged
              expect(form.body["ja"]).to include(global_id)
              expect(form.body["en"]).to include(global_id)
            end
          end
        end

        describe "form validation" do
          it "is valid with proper attributes" do
            form = subject
            expect(form).to be_valid
          end
        end
      end
    end
  end
end
