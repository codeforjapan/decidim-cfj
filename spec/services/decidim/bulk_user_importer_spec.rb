# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::BulkUserImporter do
  subject(:importer) { described_class.new(organization:) }

  let(:organization) { create(:organization, tos_version: Time.current) }
  let(:email) { "taro.yamada@example.com" }

  describe "#import" do
    context "with a single email" do
      subject(:result) { importer.import([{ email: }]).first }

      let(:user) { Decidim::User.find_by(organization:, email:) }

      it "creates a user that can sign in right away" do
        expect(result.status).to eq(:created)
        expect(user).to be_present
        expect(user).to be_confirmed
        expect(user).to be_tos_accepted
        expect(user.newsletter_notifications_at).to be_nil
        expect(user.managed).to be(false)
        expect(user).to be_active_for_authentication
        expect(user.valid_password?(result.password)).to be(true)
      end

      it "does not send any email" do
        expect { result }.not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "generates a name and a nickname from the local part" do
        expect(result.name).to eq("Taro Yamada")
        expect(result.nickname).to eq("taro_yamada")
      end
    end

    context "when a block is given" do
      let(:rows) { [{ email: }, { email: "hanako@example.com" }] }

      it "yields each result as soon as the row is processed" do
        yielded = []

        results = importer.import(rows) do |result|
          yielded << [result, Decidim::User.count]
        end

        expect(yielded.map(&:first)).to eq(results)
        expect(yielded.map(&:last)).to eq([1, 2])
      end
    end

    context "when saving raises an unexpected error" do
      subject(:results) { failing_importer.import([{ email: "first@example.com" }, { email: }]) }

      let(:failing_importer) { described_class.new(organization:) }

      before do
        allow(failing_importer).to receive(:create_user).and_wrap_original do |original, row, target_email|
          raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint" if target_email == "first@example.com"

          original.call(row, target_email)
        end
      end

      it "marks only that row as failed and keeps processing the rest" do
        expect(results.first.status).to eq(:failed)
        expect(results.first.error).to include("ActiveRecord::RecordNotUnique")
        expect(results.last.status).to eq(:created)
      end
    end

    context "when the same email is imported twice" do
      subject(:results) { importer.import([{ email: }]) }

      before { importer.import([{ email: }]) }

      it "skips the second import without creating a duplicate" do
        expect { results }.not_to change(Decidim::User, :count)
        expect(results.first.status).to eq(:skipped)
        expect(results.first.error).to eq("already exists")
      end
    end

    context "when a row has a blank email" do
      subject(:results) { importer.import([{ email: "" }, { email: }]) }

      it "skips that row and keeps processing the rest" do
        expect(results.first.status).to eq(:skipped)
        expect(results.first.error).to eq("blank email")
        expect(results.last.status).to eq(:created)
      end
    end

    context "when two emails share the same local part" do
      subject(:results) do
        importer.import([{ email: "john.doe@example.com" }, { email: "john.doe@example.org" }])
      end

      it "makes the nicknames unique within the organization" do
        expect(results.map(&:status)).to eq([:created, :created])
        expect(results.map(&:nickname)).to eq(%w(john_doe john_doe_2))
      end
    end

    context "when the local part contains symbols" do
      subject(:result) { importer.import([{ email: "weird+tag.name@example.com" }]).first }

      it "normalizes the nickname" do
        expect(result.status).to eq(:created)
        expect(result.nickname).to match(/\A[a-z0-9_\-]+\z/)
        expect(result.nickname.length).to be <= 20
      end
    end

    context "when the password is generated" do
      subject(:password) { importer.import([{ email: }]).first.password }

      it "satisfies the password validator constraints" do
        expect(password.length).to be >= 10
        expect(password.chars.uniq.length).to be >= 5
        expect(password.downcase).not_to include("taro.yamada")
        expect(password.downcase).not_to include("example")
      end
    end

    context "when the name, the nickname and the organization host could leak into the password" do
      subject(:result) { importer.import([{ email:, name: "Yamada Taro", nickname: "yamadataro" }]).first }

      let(:organization) { create(:organization, host: "participation.example.org", tos_version: Time.current) }

      it "excludes all of them from the generated password" do
        downcased = result.password.downcase

        expect(result.status).to eq(:created)
        expect(downcased).not_to include("yamadataro") # name_included_in_password? (name without spaces)
        expect(downcased).not_to include("yamada") # name_included_in_password? (name part)
        expect(downcased).not_to include("taro") # nickname_included_in_password? もカバーする
        expect(downcased).not_to include("participation") # domain_included_in_password? (組織ホストのラベル)
      end
    end

    context "when a random candidate collides with a forbidden fragment" do
      subject(:result) { generator.import([{ email:, name: "Yamada Taro", nickname: "yamadataro" }]).first }

      let(:organization) { create(:organization, host: "participation.example.org", tos_version: Time.current) }
      let(:generator) { described_class.new(organization:) }
      let(:candidates) do
        [
          "Zx3YamadaQw7T", # name_included_in_password?
          "Zx3yamadataroQ7", # nickname_included_in_password?
          "Zx3participationQ", # domain_included_in_password? (組織ホスト)
          "Zx3exampleQw7T", # email_included_in_password? (メールドメイン)
          "Kq7WmZ2rTx9BvN4d" # どれにも該当しない
        ]
      end

      before { allow(generator).to receive(:random_password).and_return(*candidates) }

      it "keeps drawing until a candidate contains none of them" do
        expect(result.password).to eq(candidates.last)
        expect(generator).to have_received(:random_password).exactly(candidates.size).times
      end
    end

    context "when a password is given" do
      subject(:result) { importer.import([{ email:, password: given_password }]).first }

      let(:given_password) { "Wg7xPq2ZrT4mKd" }

      it "uses it as is" do
        expect(result.password).to eq(given_password)
        expect(Decidim::User.find_by(organization:, email:).valid_password?(given_password)).to be(true)
      end
    end

    context "when an email is invalid" do
      subject(:results) { importer.import([{ email: "not-an-email" }, { email: }]) }

      it "marks only that row as failed" do
        expect(results.first.status).to eq(:failed)
        expect(results.first.error).to be_present
        expect(results.last.status).to eq(:created)
      end
    end
  end
end
