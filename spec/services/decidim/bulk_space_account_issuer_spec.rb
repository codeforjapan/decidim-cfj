# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::BulkSpaceAccountIssuer do
  subject(:issuer) { described_class.new(organization:, email_domain: "chiba-mirai") }

  let(:organization) { create(:organization, tos_version: Time.current) }
  let!(:assembly) do
    create(:assembly, organization:, slug: "a-high", private_space: true, is_transparent: false)
  end

  def instruction(role:, count:, slug: "a-high", type: "assemblies")
    { space_type: type, space_slug: slug, role:, count: }
  end

  describe "#issue" do
    context "with participants" do
      subject(:results) { issuer.issue([instruction(role: "participant", count: 2)]) }

      it "creates accounts with zero-padded sequential ids" do
        expect(results.map(&:status)).to eq([:created, :created])
        expect(results.map(&:account_id)).to eq(%w(a-high-001 a-high-002))
        expect(results.map(&:email)).to eq(%w(a-high-001@chiba-mirai a-high-002@chiba-mirai))
      end

      it "creates confirmed users that can sign in with the issued password" do
        result = results.first
        user = Decidim::User.find_by(organization:, email: result.email)

        expect(user).to be_confirmed
        expect(user).to be_tos_accepted
        expect(user.nickname).to eq(result.account_id)
        expect(user.name).to eq(result.account_id)
        expect(user.notifications_sending_frequency).to eq("none")
        expect(user.valid_password?(result.password)).to be(true)
      end

      it "generates readable passwords and matching furigana" do
        result = results.first

        expect(result.password).to match(/\A[A-HJKMNPR-TV-Z2-9]{10}\z/)
        expected = result.password.chars.map { |c| described_class::FURIGANA.fetch(c) }.join("・")
        expect(result.furigana).to eq(expected)
        expect(result.furigana.split("・").size).to eq(10)
      end

      it "registers them as unpublished private users without any admin role" do
        users = results.map { |r| Decidim::User.find_by(organization:, email: r.email) }

        users.each do |user|
          record = Decidim::ParticipatorySpacePrivateUser.find_by(user:, privatable_to: assembly)
          expect(record).to be_present
          expect(record.published).to be(false)
          expect(assembly.can_participate?(user)).to be(true)
        end
        expect(Decidim::AssemblyUserRole.where(user: users)).to be_empty
      end
    end

    context "with admins" do
      subject(:result) { issuer.issue([instruction(role: "admin", count: 1)]).first }

      let(:user) { Decidim::User.find_by(organization:, email: result.email) }

      it "uses the admin id format" do
        expect(result.account_id).to eq("a-high-a001")
      end

      it "creates the space role, the private user registration and the follow together" do
        expect(Decidim::AssemblyUserRole.exists?(user:, assembly:, role: "admin")).to be(true)
        # AssemblyUserRole だけでは can_participate? が false のままなので、private user 登録が必須
        expect(assembly.can_participate?(user)).to be(true)
        expect(Decidim::Follow.exists?(user:, followable: assembly)).to be(true)
      end
    end

    context "when accounts of the same format already exist" do
      before do
        create(:user, organization:, nickname: "a-high-007")
        create(:user, organization:, nickname: "a-high-a003")
      end

      it "continues participant numbering after the existing maximum, ignoring admin ids" do
        results = issuer.issue([instruction(role: "participant", count: 1)])
        expect(results.first.account_id).to eq("a-high-008")
      end

      it "continues admin numbering independently" do
        results = issuer.issue([instruction(role: "admin", count: 1)])
        expect(results.first.account_id).to eq("a-high-a004")
      end
    end

    context "with a public space" do
      let!(:assembly) do
        create(:assembly, organization:, slug: "a-high", private_space: false)
      end

      it "does not create private user registrations" do
        result = issuer.issue([instruction(role: "participant", count: 1)]).first
        user = Decidim::User.find_by(organization:, email: result.email)

        expect(result.status).to eq(:created)
        expect(Decidim::ParticipatorySpacePrivateUser.where(user:)).to be_empty
      end
    end

    context "with dry_run" do
      subject(:issuer) { described_class.new(organization:, email_domain: "chiba-mirai", dry_run: true) }

      it "plans ids without creating anything" do
        results = nil
        expect do
          results = issuer.issue([instruction(role: "participant", count: 2)])
        end.not_to change(Decidim::User, :count)

        expect(results.map(&:status)).to eq([:planned, :planned])
        expect(results.map(&:account_id)).to eq(%w(a-high-001 a-high-002))
        expect(results.map(&:password)).to eq([nil, nil])
      end
    end

    context "when the slug does not exist in the organization" do
      it "raises without creating anything" do
        expect do
          issuer.issue([instruction(role: "participant", count: 1, slug: "nope")])
        end.to raise_error(ArgumentError, /not found/)
      end
    end

    context "when the slug is longer than 15 characters" do
      it "raises instead of truncating" do
        expect do
          issuer.issue([instruction(role: "participant", count: 1, slug: "a" * 16)])
        end.to raise_error(ArgumentError, /longer than 15/)
      end
    end

    context "when one instruction is invalid among many" do
      it "creates nothing at all" do
        expect do
          issuer.issue([instruction(role: "participant", count: 1),
                        instruction(role: "chancellor", count: 1)])
        rescue ArgumentError
          nil
        end.not_to change(Decidim::User, :count)
      end
    end

    context "when linking the space fails" do
      before do
        allow(Decidim::ParticipatorySpacePrivateUser).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls the whole account back instead of leaving an unlinked user" do
        results = nil
        expect do
          results = issuer.issue([instruction(role: "participant", count: 1)])
        end.not_to change(Decidim::User, :count)

        expect(results.first.status).to eq(:failed)
      end
    end

    context "when the generated email already exists with a different nickname" do
      before { create(:user, organization:, email: "a-high-001@chiba-mirai", nickname: "someone-else") }

      it "fails that row instead of hijacking the existing account" do
        results = issuer.issue([instruction(role: "participant", count: 1)])

        expect(results.first.status).to eq(:failed)
        expect(results.first.error).to include("already exists")
      end
    end

    context "when a block is given" do
      it "yields each result as it is issued" do
        yielded = []
        results = issuer.issue([instruction(role: "participant", count: 2)]) { |r| yielded << r }
        expect(yielded).to eq(results)
      end
    end
  end

  describe "#initialize" do
    it "requires an email domain" do
      expect { described_class.new(organization:, email_domain: "") }
        .to raise_error(ArgumentError, /email_domain/)
    end
  end
end
