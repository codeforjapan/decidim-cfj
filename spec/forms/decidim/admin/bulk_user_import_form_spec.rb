# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Admin
    describe BulkUserImportForm do
      subject(:form) do
        described_class.from_params(bulk_user_import: { file: }).with_context(current_organization: organization)
      end

      let(:organization) { create(:organization, tos_version: Time.current) }
      let(:file) { uploaded_file_from_string(csv_body) }
      let(:csv_body) { "email,name\ntaro.yamada@example.com,山田 太郎\n" }

      describe "validations" do
        it { is_expected.to be_valid }

        context "without a file" do
          let(:file) { nil }

          it "requires a file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :blank)).to be(true)
          end
        end

        context "when the extension is not .csv" do
          let(:file) { uploaded_file_from_string(csv_body, filename: "users.txt", type: "text/plain") }

          it "rejects the file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :invalid_extension)).to be(true)
          end
        end

        context "when the file is larger than the size limit" do
          let(:csv_body) { "email\n#{"a" * described_class::MAX_FILE_SIZE}@example.com\n" }

          it "rejects the file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :file_too_large)).to be(true)
          end
        end

        context "when the CSV is malformed" do
          let(:csv_body) { %(email,name\n"unterminated,山田 太郎\n) }

          it "rejects the file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :malformed_csv)).to be(true)
          end
        end

        context "when the CSV has no email header" do
          let(:csv_body) { "name\n山田 太郎\n" }

          it "rejects the file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :missing_email_header)).to be(true)
          end
        end

        context "when the CSV has no data rows" do
          let(:csv_body) { "email\n" }

          it "rejects the file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :empty_csv)).to be(true)
          end
        end

        context "when the CSV has more rows than the limit" do
          let(:csv_body) do
            rows = Array.new(described_class::MAX_ROWS + 1) { |index| "user#{index}@example.com" }
            "email\n#{rows.join("\n")}\n"
          end

          it "rejects the file" do
            expect(form).not_to be_valid
            expect(form.errors.of_kind?(:file, :too_many_rows)).to be(true)
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

      describe "#rows" do
        it "returns the importable columns" do
          expect(form.rows).to eq(
            [{ email: "taro.yamada@example.com", name: "山田 太郎", nickname: nil, password: nil }]
          )
        end

        context "with a UTF-8 BOM" do
          let(:csv_body) { "\uFEFFemail,name\ntaro.yamada@example.com,山田 太郎\n" }

          it "strips the BOM" do
            expect(form).to be_valid
            expect(form.rows.first[:email]).to eq("taro.yamada@example.com")
          end
        end
      end
    end
  end
end
