# frozen_string_literal: true

require "rails_helper"

require_relative "../../../../shared/proposal_form_examples"

module Decidim
  module Proposals
    module Admin
      describe ProposalForm do
        describe "shared examples in official Decidim repository", skip: "temporarily ignore" do
          before { Rails.application.config.i18n.default_locale = Decidim.default_locale = :en }

          after { Rails.application.config.i18n.default_locale = Decidim.default_locale = :ja }

          it_behaves_like "a proposal form", skip_etiquette_validation: true, i18n: true, admin: true
          it_behaves_like "a proposal form with meeting as author", skip_etiquette_validation: true, i18n: true, admin: true
        end

        # [0.32 upgrade Phase 1] タイトル最小文字数(8) は decidim-decidim_awesome の
        # validate_title_min_length 由来。gem 無効化中は上流既定の 15 文字になるためスキップする。
        # gem 復帰時にこの skip 条件を外す。
        describe "minimum title length", skip: (defined?(Decidim::DecidimAwesome) ? false : "decidim_awesome disabled") do
          subject { form }

          let(:organization) { create(:organization) }
          let(:participatory_space) { create(:participatory_process, :with_steps, organization:) }
          let(:component) { create(:proposal_component, participatory_space:) }
          let(:title) { { ja: "提案のテスト・１", en: "This is a simple sample proposals" } }
          let(:body) { { ja: "提案のテストその１です。タイトルの文字数をテストします。", en: "This is a simple sample proposals.  This proposal should be valid." } }
          let(:created_in_meeting) { true }
          let(:meeting_component) { create(:meeting_component, participatory_space:) }
          let(:author) { create(:meeting, :published, component: meeting_component) }
          let!(:meeting_as_author) { author }

          let(:params) do
            {
              title:,
              body:,
              created_in_meeting:,
              author: meeting_as_author,
              meeting_id: author.id
            }
          end

          let(:form) do
            described_class.from_params(params).with_context(
              current_component: component,
              current_organization: component.organization,
              current_participatory_space: participatory_space
            )
          end

          context "when everything is OK" do
            it { is_expected.to be_valid }
          end

          context "when title is too short" do
            let(:title) { { ja: "提案のテスト１", en: "This is a simple sample proposals" } }

            it { is_expected.not_to be_valid }

            it "only adds errors to this field" do
              subject.valid?
              expect(subject.errors.attribute_names).to eq [:title_ja]
            end
          end
        end
      end
    end
  end
end
