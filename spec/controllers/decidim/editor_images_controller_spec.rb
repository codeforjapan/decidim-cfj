# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe EditorImagesController do
    routes { Decidim::Core::Engine.routes }

    let(:organization) { create(:organization) }
    let(:user) { create(:user, :admin, organization:) }

    before do
      request.env["decidim.current_organization"] = organization
      request.env["decidim.current_user"] = user
      sign_in user, scope: :user

      # Set up admin permissions context
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_organization).and_return(organization)
    end

    describe "POST #create" do
      let(:image_file) { fixture_file_upload("city.jpeg", "image/jpeg") }
      let(:params) { { image: image_file } }

      it "returns a permanent Rails blob URL instead of signed URL" do
        post :create, params:, format: :json

        expect(response).to have_http_status(:ok)

        json_response = response.parsed_body
        expect(json_response).to have_key("url")
        expect(json_response).to have_key("message")

        # Check that the URL is a Rails blob URL, not a signed S3 URL
        url = json_response["url"]
        expect(url).to start_with("/rails/active_storage/blobs/")
        expect(url).not_to match(/amazonaws\.com/)
        expect(url).not_to match(/\?.*signature=/)
      end

      it "creates an EditorImage record" do
        expect do
          post :create, params:, format: :json
        end.to change(Decidim::EditorImage, :count).by(1)

        editor_image = Decidim::EditorImage.last
        expect(editor_image.file).to be_attached
        expect(editor_image.decidim_author_id).to eq(user.id)
      end
    end
  end
end
