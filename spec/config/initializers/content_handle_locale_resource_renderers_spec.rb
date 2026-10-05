# frozen_string_literal: true

require "rails_helper"

describe "content_handle_locale のリソース Global ID 解決" do
  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:proposal_component) { create(:proposal_component, participatory_space: participatory_process) }
  let(:proposal) { create(:proposal, component: proposal_component) }
  let(:proposal_path) { Decidim::ResourceLocatorPresenter.new(proposal).path }

  let(:meeting_component) { create(:meeting_component, participatory_space: participatory_process) }
  let(:meeting) { create(:meeting, component: meeting_component, description: { "ja" => body }) }

  def rendered = Decidim::Meetings::MeetingPresenter.new(meeting).description(links: true)

  # gid が残っていると sanitize で href ごと落ちるため、そこまで通して確認する。
  def sanitized = ActionController::Base.helpers.sanitize(rendered, scrubber: Decidim::AdminInputScrubber.new)

  describe "href に入った gid" do
    let(:body) { %(<p>そして、<a href="#{proposal.to_global_id}">リンクテスト（内部）</a></p>) }

    it "リンク先に解決される" do
      expect(rendered).to include(%(href="#{proposal_path}"))
      expect(rendered).not_to include("gid://")
    end

    it "sanitize を越えて href が残る" do
      expect(sanitized).to include(%(href="#{proposal_path}"))
    end
  end

  describe "会議への gid" do
    let(:other_meeting) { create(:meeting, component: meeting_component) }
    let(:body) { %(<p><a href="#{other_meeting.to_global_id}">会議へ</a></p>) }

    it "提案と同じく解決される" do
      expect(sanitized).to include(Decidim::ResourceLocatorPresenter.new(other_meeting).path)
      expect(sanitized).not_to include("gid://")
    end
  end

  describe "本文テキスト中の gid" do
    let(:body) { %(<p>参考 #{proposal.to_global_id} です</p>) }

    it "従来どおりリンクとして描画される" do
      expect(rendered).to include(proposal_path)
    end
  end

  describe "gid を含まない本文" do
    let(:body) { %(<p>ふつうの<a href="https://example.com">リンク</a>です</p>) }

    it "そのまま描画される" do
      expect(rendered).to include("https://example.com")
    end
  end

  describe "解決できない gid" do
    let(:body) { %(<p><a href="gid://decidim-app/Decidim::Proposals::Proposal/999999">x</a></p>) }

    it "例外にならない" do
      expect { sanitized }.not_to raise_error
    end
  end
end
