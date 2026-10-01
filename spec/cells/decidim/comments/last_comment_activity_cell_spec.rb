# frozen_string_literal: true

require "rails_helper"
require "decidim/budgets/test/factories"

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
        it "is renderable" do
          expect(my_cell.renderable?).to be(true)
        end

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

        # Asserted separately from the rendering below: Decidim::ActivityCell#show
        # rescues NoMethodError, so rendering would come out empty even without
        # this guard — at the cost of an error log on every request. Pinning
        # renderable? keeps the guard from silently rotting away.
        it "is not renderable" do
          expect(my_cell.renderable?).to be(false)
        end

        it "does not raise" do
          expect { my_cell.call }.not_to raise_error
        end

        it "renders nothing" do
          expect(my_cell.call).to have_no_css("[data-activity]")
        end
      end

      # Trashing the commented resource on its own leaves its component in
      # place, but the comment's root_commentable now resolves to nil.
      context "when the commented resource itself has been trashed" do
        before { debate.destroy }

        it "is not renderable" do
          expect(my_cell.renderable?).to be(false)
        end

        it "renders nothing" do
          expect(my_cell.call).to have_no_css("[data-activity]")
        end
      end

      # Budgets projects reach their path through `polymorphic_resource_path`
      # instead of `resource_locator`, but that route is built from the budget's
      # component and so breaks in exactly the same way. The project reads its
      # component through `has_one :component, through: :budget`.
      context "when the commented resource is a budgets project" do
        let(:component) { create(:budgets_component, participatory_space: assembly) }
        let(:budget) { create(:budget, component:) }
        let(:project) { create(:project, budget:) }
        let(:comment) { create(:comment, commentable: project) }

        it "renders a link to the project" do
          expect(my_cell.call).to have_css("a[href^='#{project.polymorphic_resource_path({})}']")
        end

        context "when its component has been trashed" do
          before { component.destroy }

          it "is not renderable" do
            expect(my_cell.renderable?).to be(false)
          end

          it "renders nothing" do
            expect(my_cell.call).to have_no_css("[data-activity]")
          end
        end
      end
    end
  end
end
