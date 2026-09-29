# frozen_string_literal: true

require "rails_helper"

module Decidim
  module ContentBlocks
    describe LastCommentCell, type: :cell do
      subject(:my_cell) { cell("decidim/content_blocks/last_comment", content_block) }

      let(:organization) { create(:organization) }
      let(:content_block) { instance_double(Decidim::ContentBlock, scope_name:, scoped_resource_id:) }
      let(:scope_name) { :homepage }
      let(:scoped_resource_id) { nil }
      let(:base_query) { instance_double(ActiveRecord::Relation) }
      let(:resource_type_query) { instance_double(ActiveRecord::Relation) }
      let(:final_query) { instance_double(ActiveRecord::Relation) }

      controller Decidim::PagesController

      before do
        allow(controller).to receive(:current_organization).and_return(organization)
        allow(controller).to receive(:current_user).and_return(nil)
        allow(Decidim::LastActivity).to receive(:new)
          .with(organization, current_user: nil)
          .and_return(instance_double(Decidim::LastActivity, query: base_query))
        allow(base_query).to receive(:where).with(resource_type: "Decidim::Comments::Comment").and_return(resource_type_query)
      end

      context "when content block belongs to homepage scope" do
        before do
          allow(resource_type_query).to receive(:where).and_return(resource_type_query)
          allow(resource_type_query).to receive(:limit).and_return(final_query)
        end

        it "does not filter comments by participatory space" do
          my_cell.send(:comments)

          expect(resource_type_query).not_to have_received(:where).with(hash_including(:participatory_space_id))
          expect(resource_type_query).to have_received(:limit).with(18)
        end
      end

      context "when content block belongs to participatory process scope" do
        let(:participatory_process) { create(:participatory_process, organization:) }
        let(:scope_name) { :participatory_process_homepage }
        let(:scoped_resource_id) { participatory_process.id }
        let(:process_scoped_query) { instance_double(ActiveRecord::Relation) }

        before do
          allow(resource_type_query).to receive(:where).and_return(process_scoped_query)
          allow(process_scoped_query).to receive(:limit).and_return(final_query)
        end

        it "filters comments by the participatory process" do
          my_cell.send(:comments)

          expect(resource_type_query).to have_received(:where).with(hash_including(
                                                                      participatory_space_type: "Decidim::ParticipatoryProcess",
                                                                      participatory_space_id: participatory_process.id
                                                                    ))
          expect(process_scoped_query).to have_received(:limit).with(18)
        end
      end

      context "when content block belongs to assembly scope" do
        let(:scope_name) { :assembly_homepage }
        let(:scoped_resource_id) { 12_345 }
        let(:assembly_scoped_query) { instance_double(ActiveRecord::Relation) }

        before do
          allow(resource_type_query).to receive(:where).and_return(assembly_scoped_query)
          allow(assembly_scoped_query).to receive(:limit).and_return(final_query)
        end

        it "filters comments by the assembly" do
          my_cell.send(:comments)

          expect(resource_type_query).to have_received(:where).with(hash_including(
                                                                      participatory_space_type: "Decidim::Assembly",
                                                                      participatory_space_id: scoped_resource_id
                                                                    ))
          expect(assembly_scoped_query).to have_received(:limit).with(18)
        end
      end

      # Comments are collected here but linked to by the activity cell. A
      # comment we cannot build a link for has to be dropped at this point, so
      # that the buffered query refills its slot instead of leaving the block
      # with a heading and no activities under it.
      describe "#visible_comment?" do
        subject(:visible) { my_cell.send(:visible_comment?, action_log) }

        let(:scope_name) { :assembly_homepage }
        let(:scoped_resource_id) { assembly.id }
        let(:assembly) { create(:assembly, organization:) }
        let(:debates_component) { create(:debates_component, participatory_space: assembly) }
        let(:debate) { create(:debate, component: debates_component) }
        let(:comment) { create(:comment, commentable: debate) }
        let(:action_log) do
          create(
            :action_log,
            organization:,
            participatory_space: assembly,
            component: debates_component,
            resource: comment,
            user: create(:user, organization:),
            action: "create",
            visibility: "public-only"
          )
        end

        before { action_log }

        it "keeps a comment whose resource can still be linked to" do
          expect(visible).to be(true)
        end

        context "when the component of the commented resource has been trashed" do
          before { debates_component.destroy }

          it "drops the comment" do
            expect(visible).to be(false)
          end
        end
      end

      # The point of dropping unlinkable comments here rather than at render
      # time: the query buffers six times what it shows, so a dropped comment
      # gives its slot back instead of leaving the block a heading with a gap
      # underneath it.
      describe "#valid_comments" do
        let(:scope_name) { :assembly_homepage }
        let(:scoped_resource_id) { assembly.id }
        let(:assembly) { create(:assembly, organization:) }
        let(:trashed_component) { create(:debates_component, participatory_space: assembly) }
        let(:live_component) { create(:debates_component, participatory_space: assembly) }

        let(:trashed_log) { comment_log_in(trashed_component) }
        let(:live_logs) { Array.new(3) { comment_log_in(live_component) } }

        def comment_log_in(component)
          debate = create(:debate, component:)
          create(
            :action_log,
            organization:,
            participatory_space: assembly,
            component:,
            resource: create(:comment, commentable: debate),
            user: create(:user, organization:),
            action: "create",
            visibility: "public-only"
          )
        end

        before do
          ids = [trashed_log, *live_logs].map(&:id)
          trashed_component.destroy
          allow(my_cell).to receive(:comments).and_return(Decidim::ActionLog.where(id: ids).order(:id))
        end

        it "fills every slot from the buffer, skipping the unlinkable comment" do
          expect(my_cell.send(:valid_comments)).to match_array(live_logs)
        end
      end
    end
  end
end
