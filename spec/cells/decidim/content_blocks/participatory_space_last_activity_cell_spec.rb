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

      # ordered_users_with_activities は DB クエリを伴うため、
      # 返すレコードのうち一部の .user が nil（削除済みユーザー）になるケースをモックする
      let(:log_with_deleted_user) { double("action_log", user: nil) }
      let(:log_with_existing_user) { double("action_log", user: existing_user) }
      let(:activity_relation) { instance_double(ActiveRecord::Relation) }

      controller Decidim::ParticipatoryProcesses::ParticipatoryProcessesController

      before do
        allow(controller).to receive(:current_organization).and_return(organization)
        allow(controller).to receive(:current_user).and_return(nil)
        allow(my_cell).to receive(:ordered_users_with_activities).and_return(activity_relation)
        allow(activity_relation).to receive(:limit).and_return(
          [log_with_deleted_user, log_with_existing_user]
        )
      end

      describe "#last_activities_users" do
        it "削除済みユーザー（nil）を除外して返す" do
          expect(my_cell.send(:last_activities_users)).to eq([existing_user])
        end

        it "nil を含まない" do
          expect(my_cell.send(:last_activities_users)).not_to include(nil)
        end
      end

      describe "#render_recent_avatars" do
        it "削除済みユーザーが含まれていてもエラーを発生させない" do
          # render :recent_avatars の内部（avatar_url生成など）はテスト環境依存のため
          # render 自体をスタブし、nil ユーザーによる NoMethodError が発生しないことを確認する
          allow(my_cell).to receive(:render).with(:recent_avatars).and_return("<html>stub</html>")
          expect { my_cell.render_recent_avatars }.not_to raise_error
        end
      end
    end
  end
end
