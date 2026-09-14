# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Assemblies
    module Admin
      describe BulkAccountIssueForm do
        subject(:form) do
          described_class.from_params(params).with_context(
            current_organization: organization,
            current_participatory_space: assembly
          )
        end

        let(:organization) { create(:organization, tos_version: Time.current) }
        let(:assembly) { create(:assembly, organization:, slug: "a-high", private_space: true, is_transparent: false) }
        let(:params) { { bulk_account_issue: { participant_count: 2, admin_count: 1 } } }

        it { is_expected.to be_valid }

        describe "validations" do
          context "with negative counts" do
            let(:params) { { bulk_account_issue: { participant_count: -1, admin_count: 2 } } }

            it "rejects the negative count" do
              expect(form).not_to be_valid
              expect(form.errors.of_kind?(:base, :negative_counts)).to be(true)
            end
          end

          context "with no accounts" do
            let(:params) { { bulk_account_issue: { participant_count: 0, admin_count: 0 } } }

            it "rejects the request" do
              expect(form).not_to be_valid
              expect(form.errors.of_kind?(:base, :no_accounts)).to be(true)
            end
          end

          context "with more accounts than the cap" do
            let(:params) { { bulk_account_issue: { participant_count: 60, admin_count: 41 } } }

            it "rejects the request" do
              expect(form).not_to be_valid
              expect(form.errors.of_kind?(:base, :too_many_accounts)).to be(true)
            end
          end

          context "with a slug longer than the id budget" do
            let(:assembly) { create(:assembly, organization:, slug: "a" * 16, private_space: true, is_transparent: false) }

            it "rejects the request" do
              expect(form).not_to be_valid
              expect(form.errors.of_kind?(:base, :slug_too_long)).to be(true)
            end
          end

          context "when the organization has no terms of service version" do
            let(:organization) { create(:organization, tos_version: nil, create_static_pages: false) }

            it "rejects the request" do
              expect(form).not_to be_valid
              expect(form.errors.of_kind?(:base, :missing_tos_version)).to be(true)
            end
          end
        end

        describe "#instructions" do
          it "returns the positive counts as issuer instructions" do
            expect(form.instructions).to eq(
              [
                { space_type: "assemblies", space_slug: "a-high", role: "participant", count: 2 },
                { space_type: "assemblies", space_slug: "a-high", role: "admin", count: 1 }
              ]
            )
          end

          context "when a count is zero" do
            let(:params) { { bulk_account_issue: { participant_count: 2, admin_count: 0 } } }

            it "drops the zero instruction" do
              expect(form.instructions).to eq(
                [{ space_type: "assemblies", space_slug: "a-high", role: "participant", count: 2 }]
              )
            end
          end
        end
      end
    end
  end
end
