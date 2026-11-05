# frozen_string_literal: true

require "csv"

module Decidim
  module Admin
    class BulkUserImportForm < Decidim::Form
      mimic :bulk_user_import

      MAX_FILE_SIZE = 1.megabyte
      MAX_ROWS = 100
      UTF8_BOM = "\xEF\xBB\xBF"

      attribute :file

      validates :file, presence: true
      validate :file_must_be_csv
      validate :file_must_be_within_size
      validate :csv_must_be_importable, if: -> { errors[:file].empty? }
      validate :organization_must_have_tos_version, if: -> { errors.empty? }

      # importer に渡す行。検証に通った場合のみ中身が入る。
      def rows
        return [] if csv.blank?

        csv.map do |row|
          { email: row["email"], name: row["name"], nickname: row["nickname"], password: row["password"] }
        end
      end

      private

      # パース結果のテーブル。検証とは独立に呼べるよう、初回に一度だけパースして使い回す。
      def csv
        parse_csv unless defined?(@csv_error)
        @csv
      end

      def file_must_be_csv
        return if file.blank? || csv_extension?

        errors.add(:file, :invalid_extension)
      end

      def file_must_be_within_size
        return if file.blank? || file.size <= MAX_FILE_SIZE

        errors.add(:file, :file_too_large, size: max_file_size)
      end

      # 同期処理のため、失敗はここで弾いて importer に渡さない。
      def csv_must_be_importable
        parse_csv
        return unless @csv_error

        if @csv_error == :too_many_rows
          errors.add(:file, :too_many_rows, max: MAX_ROWS)
        else
          errors.add(:file, @csv_error)
        end
      end

      # 構造を検証しつつ、成功すればテーブルを @csv に、失敗すれば理由を @csv_error に残す。
      def parse_csv
        @csv_error = nil
        content = read_utf8
        return @csv_error = :malformed_csv if content.blank?

        table = CSV.parse(content, headers: true)
        return @csv_error = :missing_email_header unless Array(table.headers).include?("email")
        return @csv_error = :too_many_rows if table.size > MAX_ROWS
        return @csv_error = :empty_csv if table.empty?

        @csv = table
      rescue CSV::MalformedCSVError
        @csv_error = :malformed_csv
      end

      def organization_must_have_tos_version
        return if current_organization.blank? || current_organization.tos_version.present?

        errors.add(:base, :missing_tos_version)
      end

      def csv_extension?
        File.extname(file.original_filename.to_s).downcase == ".csv"
      end

      def read_utf8
        content = file.read.to_s.b.delete_prefix(UTF8_BOM.b).force_encoding(Encoding::UTF_8)
        return unless content.valid_encoding?

        content
      end

      def max_file_size
        ActiveSupport::NumberHelper.number_to_human_size(MAX_FILE_SIZE)
      end
    end
  end
end
