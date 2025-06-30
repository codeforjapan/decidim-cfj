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

        let(:params) do
          {
            title: { "ja" => "テストタイトル", "en" => "Test Title" },
            body: { "ja" => "<p>テスト内容</p>", "en" => "<p>Test content</p>" },
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
