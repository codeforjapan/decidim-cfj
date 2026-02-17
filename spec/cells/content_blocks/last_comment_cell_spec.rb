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
    end
  end
end
