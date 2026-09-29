# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Comments
    describe LastCommentActivityCell, type: :cell do
      subject(:my_cell) { cell("decidim/comments/last_comment_activity", action_log, context: { show_author: false }) }

      let(:organization) { create(:organization) }
      let(:assembly) { create(:assembly, organization:) }
      let(:component) { create(:debates_component, participatory_space: assembly) }
      let(:debate) { create(:debate, component:) }
      let(:comment) { create(:comment, commentable: debate) }
      let(:action_log) do
        create(
          :action_log,
          organization:,
          participatory_space: assembly,
          component:,
          resource: comment,
          user: create(:user, organization:),
          action: "create",
          visibility: "public-only"
        )
      end

      controller Decidim::Assemblies::AssembliesController

      before do
        allow(controller).to receive(:current_organization).and_return(organization)
        allow(controller).to receive(:current_user).and_return(nil)

        action_log # build the whole graph while the component is still present
      end

      context "when the commented resource is reachable" do
        it "renders a link to the commented resource" do
          expect(my_cell.call).to have_css("a[href^='#{Decidim::ResourceLocatorPresenter.new(debate).path}']")
        end
      end

      # Trashing a component soft-deletes it, so the resources inside it can no
      # longer be routed: `debate.component` returns nil and the route helpers
      # fall back to calling `mounted_engine` on the debate itself, which does
      # not implement it. The comment and its action log survive the trashing,
      # so the activity still reaches this cell.
      context "when the component of the commented resource has been trashed" do
        before { component.destroy }

        it "does not raise" do
          expect { my_cell.call }.not_to raise_error
        end

        it "renders nothing" do
          expect(my_cell.call).to have_no_css("[data-activity]")
        end
      end
    end
  end
end
