# frozen_string_literal: true

require "spec_helper"

module Decidim::DecidimAwesome
  describe ContentBlocks::MapCell, type: :cell do
    subject { cell(content_block.cell, content_block).call }

    let(:organization) { create(:organization) }
    let(:content_block) { create(:content_block, organization:, manifest_name: :awesome_map, scope_name: :homepage, settings:) }
    let(:settings) { {} }
    let!(:participatory_process) { create(:participatory_process, organization:) }
    let!(:category) { create(:category, participatory_space: participatory_process) }
    let!(:proposal_component) { create(:proposal_component, :with_geocoding_enabled, participatory_space: participatory_process) }
    let!(:meeting_component) { create(:meeting_component, participatory_space: participatory_process) }
    let!(:proposal) { create(:proposal, component: proposal_component) }
    let!(:meeting) { create(:meeting, component: meeting_component) }

    controller Decidim::PagesController

    before do
      allow(controller).to receive(:current_organization).and_return(organization)
    end

    it "shows the map" do
      expect(subject).to have_css("#awesome-map")
      expect(subject).to have_content("window.AwesomeMap.categories")
    end

    it "do not show the title" do
      expect(subject).not_to have_css("h3.section-heading")
    end

    it "uses default height" do
      expect(subject).to have_content("height: 500px;")
    end

    it "uses default data-options" do
      expect(subject.to_s).to include('data-truncate="255"')
      expect(subject.to_s).to include('data-map-center=""')
      expect(subject.to_s).to include('data-map-zoom="8"')
      expect(subject.to_s).to include('data-menu-amendments="true"')
      expect(subject.to_s).to include('data-menu-meetings="true"')
      expect(subject.to_s).to include('data-show-not-answered="true"')
      expect(subject.to_s).to include('data-show-accepted="true"')
      expect(subject.to_s).to include('data-show-evaluating="true"')
      expect(subject.to_s).to include('data-show-withdrawn="false"')
      expect(subject.to_s).to include('data-show-rejected="false"')
    end

    it "uses all components" do
      components = JSON.parse(subject.to_s.match(/data-components='(.*)'/)[1])

      expect(components.pluck("id")).to include(meeting_component.id)
      expect(components.pluck("id")).to include(proposal_component.id)
    end

    it "uses all categories" do
      categories = JSON.parse(subject.to_s.match(/window\.AwesomeMap\.categories = (\[.*\])/)[1])

      expect(categories.pluck("id")).to include(category.id)
    end

    context "when the content block has a title" do
      let(:settings) do
        {
          "title" => { "en" => "Look this beautiful map!" }
        }
      end

      it "shows the title" do
        expect(subject).to have_css("h3.section-heading")
        expect(subject).to have_content("Look this beautiful map!")
      end
    end

    context "when a height is defined" do
      let(:settings) do
        {
          map_height: 734
        }
      end

      it "uses default height" do
        expect(subject).not_to have_content("height: 500px;")
        expect(subject).to have_content("height: 734px;")
      end
    end

    context "when data-options are customized" do
      let(:settings) do
        {
          truncate: 123,
          map_center: "41.1,2.3",
          map_zoom: 12,
          menu_amendments: false,
          menu_meetings: false,
          show_not_answered: false,
          show_accepted: false,
          show_evaluating: false,
          show_withdrawn: true,
          show_rejected: true
        }
      end

      it "uses default data-options" do
        expect(subject.to_s).to include('data-truncate="123"')
        expect(subject.to_s).to include('data-map-center="41.1,2.3"')
        expect(subject.to_s).to include('data-map-zoom="12"')
        expect(subject.to_s).to include('data-menu-amendments="false"')
        expect(subject.to_s).to include('data-menu-meetings="false"')
        expect(subject.to_s).to include('data-show-not-answered="false"')
        expect(subject.to_s).to include('data-show-accepted="false"')
        expect(subject.to_s).to include('data-show-evaluating="false"')
        expect(subject.to_s).to include('data-show-withdrawn="true"')
        expect(subject.to_s).to include('data-show-rejected="true"')
      end
    end

    context "with another organization" do
      subject { cell(another_content_block.cell, another_content_block).call }

      let(:another_organization) { create(:organization) }
      let(:another_content_block) { create(:content_block, organization: another_organization, manifest_name: :awesome_map, scope_name: :homepage, settings:) }
      let(:another_participatory_process) { create(:participatory_process, organization: another_organization) }
      let!(:another_meeting_component) { create(:meeting_component, participatory_space: another_participatory_process) }

      before do
        allow(controller).to receive(:current_organization).and_return(another_organization)
      end

      it "uses its own components" do
        components = JSON.parse(subject.to_s.match(/data-components='(.*)'/)[1])

        expect(components.pluck("id")).not_to include(meeting_component.id)
        expect(components.pluck("id")).not_to include(proposal_component.id)
        expect(components.pluck("id")).to include(another_meeting_component.id)
      end
    end
  end
end
