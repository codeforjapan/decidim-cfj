# frozen_string_literal: true

require "rails_helper"
require "decidim/conferences/test/factories"

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
          allow(resource_type_query).to receive(:or).and_return(resource_type_query)
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
          allow(process_scoped_query).to receive(:where).and_return(process_scoped_query)
          allow(process_scoped_query).to receive(:or).and_return(process_scoped_query)
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
          allow(assembly_scoped_query).to receive(:where).and_return(assembly_scoped_query)
          allow(assembly_scoped_query).to receive(:or).and_return(assembly_scoped_query)
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

      # Trashing a component (or a space, which trashes its components) leaves
      # all of its comments unlinkable at once. They are dropped in SQL so that
      # they cannot use up the buffer that #valid_comments refills from.
      describe "#comments" do
        subject(:comments) { my_cell.send(:comments) }

        let(:user) { create(:user, organization:) }
        let(:assembly) { create(:assembly, organization:) }
        let(:live_component) { create(:debates_component, participatory_space: assembly) }
        let(:trashed_component) { create(:debates_component, participatory_space: assembly) }
        let(:live_comment) { create(:comment, commentable: create(:debate, component: live_component)) }
        let(:trashed_comment) { create(:comment, commentable: create(:debate, component: trashed_component)) }

        # Older than every trashed log and outnumbered by them beyond the
        # buffer, so it only makes it into the query if they are dropped in SQL.
        let!(:live_log) do
          create(:action_log, user:, participatory_space: assembly, component: live_component,
                              resource: live_comment, visibility: "public-only")
        end
        let!(:trashed_logs) do
          create_list(:action_log, 20, user:, participatory_space: assembly, component: trashed_component,
                                       resource: trashed_comment, visibility: "public-only")
        end

        before do
          allow(Decidim::LastActivity).to receive(:new).and_call_original
          trashed_component.destroy
        end

        context "when content block belongs to homepage scope" do
          it "drops every comment in the trashed component" do
            expect(comments).to contain_exactly(live_log)
          end
        end

        context "when content block belongs to assembly scope" do
          let(:scope_name) { :assembly_homepage }
          let(:scoped_resource_id) { assembly.id }

          it "drops every comment in the trashed component" do
            expect(comments).to contain_exactly(live_log)
          end
        end

        # Decidim::LastActivity#filter_spaces drops logs of trashed spaces only
        # when they have private users, which conferences do not. They are
        # dropped anyway because trashing a space trashes its components.
        context "when a conference has been trashed" do
          let(:conference) { create(:conference, organization:) }
          let(:conference_component) { create(:debates_component, participatory_space: conference) }
          let(:conference_comment) { create(:comment, commentable: create(:debate, component: conference_component)) }
          let!(:conference_log) do
            create(:action_log, user:, participatory_space: conference, component: conference_component,
                                resource: conference_comment, visibility: "public-only")
          end

          before { conference.destroy }

          it "drops the comments in it" do
            expect(comments).not_to include(conference_log)
          end
        end
      end

      # A commented resource can also be trashed on its own, which SQL does not
      # see. Such a comment has to be dropped here rather than at render time,
      # so that the buffered query refills its slot instead of leaving the
      # block with a gap or with a heading and no activities under it.
      describe "#valid_comments" do
        let(:user) { create(:user, organization:) }
        let(:assembly) { create(:assembly, :published, organization:) }
        let(:component) { create(:debates_component, :published, participatory_space: assembly) }
        let(:trashed_debate) { create(:debate, component:) }
        let(:trashed_comment) { create(:comment, commentable: trashed_debate) }
        let(:live_comment) { create(:comment, commentable: create(:debate, component:)) }
        let(:trashed_log) do
          create(:action_log, user:, participatory_space: assembly, component:,
                              resource: trashed_comment, visibility: "public-only")
        end
        let(:live_logs) do
          create_list(:action_log, 3, user:, participatory_space: assembly, component:,
                                      resource: live_comment, visibility: "public-only")
        end

        before do
          ids = [trashed_log, *live_logs].map(&:id)
          trashed_debate.destroy
          allow(my_cell).to receive(:comments).and_return(Decidim::ActionLog.where(id: ids).order(:id))
        end

        context "when content block belongs to homepage scope" do
          it "fills every slot from the buffer, skipping the unlinkable comment" do
            expect(my_cell.send(:valid_comments)).to match_array(live_logs)
          end
        end

        context "when content block belongs to assembly scope" do
          let(:scope_name) { :assembly_homepage }
          let(:scoped_resource_id) { assembly.id }

          it "fills every slot from the buffer, skipping the unlinkable comment" do
            expect(my_cell.send(:valid_comments)).to match_array(live_logs)
          end
        end
      end
    end
  end
end
