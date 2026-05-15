# frozen_string_literal: true

require "rails_helper"

module Decidim
  module ContentBlocks
    describe ParticipatorySpaceLastActivityCell, type: :cell do
      subject(:my_cell) do
        cell(
          "decidim/content_blocks/participatory_space_last_activity",
          content_block,
          base_model: Decidim::ParticipatoryProcess
        )
      end

      let(:organization) { create(:organization) }
      let(:participatory_process) { create(:participatory_process, organization:) }
      let(:content_block) do
        create(
          :content_block,
          organization:,
          manifest_name: :last_activity,
          scope_name: :participatory_process_homepage,
          scoped_resource_id: participatory_process.id
        )
      end
      let(:existing_user) { create(:user, organization:) }

      # Force-deleted in the before block
      let(:deleted_user) { create(:user, organization:) }

      controller Decidim::ParticipatoryProcesses::ParticipatoryProcessesController

      before do
        allow(controller).to receive(:current_organization).and_return(organization)
        allow(controller).to receive(:current_user).and_return(nil)

        # Overrides to pass Decidim::LastActivity#query filters
        common_attrs = {
          organization:,
          participatory_space: participatory_process,
          resource: participatory_process,
          action: "publish",
          visibility: "all"
        }
        create(:action_log, **common_attrs, user: existing_user)
        create(:action_log, **common_attrs, user: deleted_user)

        deleted_user.destroy!
      end

      describe "#last_activities_users" do
        it "excludes deleted users whose user association resolves to nil" do
          expect(my_cell.send(:last_activities_users)).to eq([existing_user])
        end

        it "does not include nil" do
          expect(my_cell.send(:last_activities_users)).not_to include(nil)
        end
      end
    end
  end
end
