# frozen_string_literal: true

require "rails_helper"

describe "content_handle_locale のリソース Global ID 解決" do
  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:proposal_component) { create(:proposal_component, participatory_space: participatory_process) }
  let(:proposal) { create(:proposal, component: proposal_component) }
  let(:proposal_url) { Decidim::ResourceLocatorPresenter.new(proposal).url }

  let(:meeting_component) { create(:meeting_component, participatory_space: participatory_process) }
  let(:meeting) { create(:meeting, component: meeting_component, description: { "ja" => body }) }

  let(:rendered) { Decidim::Meetings::MeetingPresenter.new(meeting).description(links: true) }
  # An unresolved gid loses its href in sanitize, so check the output after it too.
  let(:sanitized) { ActionController::Base.helpers.sanitize(rendered, scrubber: Decidim::AdminInputScrubber.new) }

  describe "href に入った gid" do
    let(:body) { %(<p>そして、<a href="#{proposal.to_global_id}">リンクテスト（内部）</a></p>) }

    it "絶対 URL に解決される" do
      expect(rendered).to include(%(href="#{proposal_url}"))
      expect(rendered).not_to include("gid://")
    end

    it "sanitize を越えて href が残る" do
      expect(sanitized).to include(%(href="#{proposal_url}"))
    end
  end

  describe "会議への gid" do
    let(:other_meeting) { create(:meeting, :published, component: meeting_component) }
    let(:body) { %(<p><a href="#{other_meeting.to_global_id}">会議へ</a></p>) }

    it "提案と同じく解決される" do
      expect(sanitized).to include(%(href="#{Decidim::ResourceLocatorPresenter.new(other_meeting).url}"))
      expect(sanitized).not_to include("gid://")
    end
  end

  describe "本文テキスト中の gid" do
    let(:body) { %(<p>参考 #{proposal.to_global_id} です</p>) }

    it "解決せず後段の ContentProcessor に任せる" do
      expect(rendered).to include(proposal.to_global_id.to_s)
      expect(rendered).not_to include("<a ")
    end
  end

  describe "gid を含まない本文" do
    let(:body) { %(<p>ふつうの<a href="https://example.com">リンク</a>です</p>) }

    it "そのまま描画される" do
      expect(rendered).to include("https://example.com")
    end
  end

  describe "解決できない gid" do
    let(:gid) { "gid://decidim-app/Decidim::Proposals::Proposal/999999" }
    let(:body) { %(<p><a href="#{gid}">x</a></p>) }

    it "gid のまま残す" do
      expect(rendered).to include(%(href="#{gid}"))
    end
  end
end
