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
        expect(user.managed).to be(false)
        expect(user).to be_active_for_authentication
        expect(user.valid_password?(result.password)).to be(true)
      end

      it "does not send or enqueue any email" do
        # deliveries はテスト環境では常に空のまま（deliver_later はジョブを積むだけで、
        # queue_adapter = :test は実行しない）なので、キューへの投入自体が無いことを検証する。
        expect { result }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "generates a name and a nickname from the local part" do
        expect(result.name).to eq("Taro Yamada")
        expect(result.nickname).to eq("taro_yamada")
      end

      it "leaves the newsletter subscription off" do
        expect(result.status).to eq(:created)
        expect(user.newsletter_notifications_at).to be_nil
      end

      it "turns notification digest emails off" do
        expect(result.status).to eq(:created)
        expect(user.notifications_sending_frequency).to eq("none")
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

    context "with a custom password charset and length" do
      subject(:result) { readable_importer.import([{ email: }]).first }

      let(:readable_importer) do
        described_class.new(organization:, password_length: 10,
                            password_charset: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars)
      end

      it "draws the password only from that charset" do
        expect(result.status).to eq(:created)
        expect(result.password).to match(/\A[A-HJ-NP-Z2-9]{10}\z/)
        expect(Decidim::User.find_by(organization:, email:).valid_password?(result.password)).to be(true)
      end
    end

    context "when a candidate collides with the common password list" do
      subject(:result) { generator.import([{ email: }]).first }

      let(:generator) { described_class.new(organization:) }
      let(:candidates) { %w(CommonCandidate123 Kq7WmZ2rTx9BvN4d) }

      before do
        allow(generator).to receive(:random_password).and_return(*candidates)
        allow(Decidim::CommonPasswords.instance).to receive(:passwords).and_return([candidates.first])
      end

      it "draws again" do
        expect(result.status).to eq(:created)
        expect(result.password).to eq(candidates.last)
      end
    end

    context "when no acceptable password can be generated" do
      subject(:results) { importer.import([{ email: }]) }

      before do
        stub_const("#{described_class}::MAX_PASSWORD_ATTEMPTS", 5)
        # 拒否リストが全候補に一致する状況を作り、再抽選が有限で打ち切られて
        # その行だけが failed になる（無限ループしない）ことを確認する。
        allow(Decidim).to receive(:denied_passwords).and_return([/.*/])
      end

      it "fails the row after a bounded number of attempts instead of looping forever" do
        expect(results.first.status).to eq(:failed)
        expect(results.first.error).to include("password")
      end
    end
  end

  describe "#initialize" do
    context "when the organization has no tos_version" do
      # 組織ファクトリは after(:create) で TOS ページ経由の tos_version を必ず設定するため、スタブで nil にする
      before { allow(organization).to receive(:tos_version).and_return(nil) }

      it "raises instead of creating users that would all count as not having accepted the TOS" do
        expect { described_class.new(organization:) }.to raise_error(ArgumentError, /tos_version/)
      end
    end

    context "when the password length is below the validator minimum" do
      it "raises" do
        expect { described_class.new(organization:, password_length: 8) }
          .to raise_error(ArgumentError, /password_length/)
      end
    end

    context "when the charset cannot satisfy the unique character constraint" do
      it "raises" do
        expect { described_class.new(organization:, password_charset: %w(A B A B)) }
          .to raise_error(ArgumentError, /password_charset/)
      end
    end
  end
end
