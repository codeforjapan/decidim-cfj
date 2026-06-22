# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe UserPresenter do
    let(:organization) { create(:organization) }

    describe "#name" do
      subject { described_class.new(user).name }

      let(:user) do
        create(:user, organization:).tap do |u|
          u.update_column(:name, "Alice<script>alert(1)</script>") # rubocop:disable Rails/SkipsModelValidations
        end
      end

      it "strips script tags" do
        expect(subject).not_to include("<script>")
        expect(subject).not_to include("</script>")
      end
    end
  end

  describe Log::UserPresenter do
    subject { described_class.new(user, view_helpers, extra) }

    let(:user) { nil }
    let(:view_helpers) { ActionController::Base.helpers }
    let(:extra) { { "name" => "Alice<script>alert(1)</script>", "nickname" => "alice" } }

    describe "#present" do
      it "strips script tags from the rendered name" do
        expect(subject.present).not_to include("<script>")
        expect(subject.present).not_to include("</script>")
      end
    end
  end

  describe UserBaseEntity do
    describe "::REGEXP_NAME" do
      it "rejects names containing a newline" do
        expect(described_class::REGEXP_NAME.match?("Alice\nBob")).to be false
      end

      it "rejects names containing a carriage return" do
        expect(described_class::REGEXP_NAME.match?("Alice\rBob")).to be false
      end

      it "accepts normal names" do
        expect(described_class::REGEXP_NAME.match?("Alice Liddell")).to be true
      end
    end
  end
end
