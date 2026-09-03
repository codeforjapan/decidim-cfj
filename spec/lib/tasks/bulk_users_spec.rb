# frozen_string_literal: true

require "rails_helper"
require "rake"

# lib/tasks/bulk_users.rake の入力・出力の扱いを検証する。
# 実際の作成処理は Decidim::BulkUserImporter 側の spec でカバーしている。
RSpec.describe "bulk_users rake tasks" do
  let(:organization) { create(:organization, tos_version: Time.current) }
  let(:tmpdir) { Dir.mktmpdir }
  let(:input) { File.join(tmpdir, "in.csv") }
  let(:output) { File.join(tmpdir, "out.csv") }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("bulk_users:import")
    Rake::Task["bulk_users:import"].reenable
    ENV["DECIDIM_ORGANIZATION_ID"] = organization.id.to_s
    ENV["IN"] = input
    ENV["OUT"] = output
  end

  after do
    %w(DECIDIM_ORGANIZATION_ID IN OUT).each { |key| ENV.delete(key) }
    FileUtils.remove_entry(tmpdir)
  end

  def run = Rake::Task["bulk_users:import"].invoke

  context "when the CSV has no email header" do
    # Excel が書き出す "Email" や日本語見出しでも、CSV::Row#[] は完全一致でしか引けない。
    before { File.write(input, "Email\ntaro@example.org\n") }

    it "aborts instead of reporting a successful no-op" do
      expect { expect { run }.to raise_error(SystemExit) }.not_to change(Decidim::User, :count)
    end

    # 出力ファイルを作ってしまうと、CSV を直して同じ OUT で再実行できなくなる。
    it "does not leave an output file behind" do
      expect { run }.to raise_error(SystemExit)

      expect(File).not_to exist(output)
    end
  end

  context "when the CSV is valid" do
    before { File.write(input, "email\ntaro@example.org\n") }

    it "creates the user" do
      expect { run }.to change(Decidim::User, :count).by(1)
    end

    # 運用者が Excel で開いて配布に使うため、日本語が化けないよう BOM を付ける。
    it "writes the output with a UTF-8 BOM" do
      run

      expect(File.binread(output, 3)).to eq("\xEF\xBB\xBF".b)
    end
  end
end
