# frozen_string_literal: true

# CSV から確定ユーザー（メール確認済み・利用規約同意済み）を一括作成する。
# 招待メール・確認メールは送信しない。詳細は docs/BULK_USER_IMPORT.md を参照。
#
# 使い方:
#   DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:import IN=tmp/bulk/emails.csv
#   DECIDIM_ORGANIZATION_NAME=<name> rails bulk_users:import IN=tmp/bulk/emails.csv OUT=tmp/bulk/created.csv
#
# 入力CSV (IN): ヘッダ行の `email` は必須。任意で `name,nickname,password` 列を追加できる。
#   email
#   taro.yamada@example.com
#   hanako@example.com
#
# 出力CSV (OUT, 既定 tmp/bulk_users/created_users_<日時>.csv): email,nickname,name,password,status,error
#   ※ 生成した平文パスワードが入る。0600 で作成される。配布が完了するまで保管し、不要になったら削除する。
#   ※ 既存ファイルへは書き込まない（上書きすると発行済みパスワードが失われるため、存在する場合は中断する）。
namespace :bulk_users do
  desc "Create confirmed users in bulk from a CSV (IN= OUT= DECIDIM_ORGANIZATION_ID= or DECIDIM_ORGANIZATION_NAME=)"
  task import: :environment do
    require "csv"

    organization = bulk_users_find_organization

    abort "組織に利用規約のバージョンが設定されていません。管理画面で利用規約を保存してから再実行してください。" if organization.tos_version.blank?

    input = ENV.fetch("IN")
    output = ENV.fetch("OUT") { "tmp/bulk_users/created_users_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.csv" }

    rows = CSV.read(input, headers: true, encoding: "bom|utf-8").map do |row|
      { email: row["email"], name: row["name"], nickname: row["nickname"], password: row["password"] }
    end

    puts "Start bulk_users:import of #{rows.count} rows from #{input}"

    importer = Decidim::BulkUserImporter.new(organization:)

    FileUtils.mkdir_p(File.dirname(output))

    # 出力CSVは、配布が完了するまで唯一のパスワードの記録として保持される（DBにはハッシュしか
    # 残らない）。上書きすると発行済みパスワードが失われるため、O_EXCL で新規作成し、既存
    # ファイルがあれば書き込まずに中断する。平文を含むので 0600 で作る。
    io = begin
      File.open(output, File::CREAT | File::EXCL | File::WRONLY, 0o600)
    rescue Errno::EEXIST
      abort "出力先 #{output} は既に存在するため中断しました。発行済みパスワードを守るため上書きはしません。別のパスを OUT= で指定してください。"
    end

    results = begin
      csv = CSV.new(io)
      csv << %w(email nickname name password status error)
      importer.import(rows) do |result|
        csv << [result.email, result.nickname, result.name, result.password, result.status, result.error]
        io.flush
      end
    ensure
      io.close
    end

    tally = results.group_by(&:status).transform_values(&:count)
    puts "created=#{tally[:created].to_i} skipped=#{tally[:skipped].to_i} failed=#{tally[:failed].to_i}"
    puts "認証情報を #{output} に出力しました。平文パスワードを含むため取り扱いに注意してください。"

    results.select { |result| result.status == :failed }.each do |result|
      warn "  FAILED #{result.email}: #{result.error}"
    end

    puts "Finish bulk_users:import"
  end
end

private

# lib/tasks/delete.rake の decidim_find_organization と同じ規約だが、
# rake のタスク定義はグローバルなので名前を分けている。
def bulk_users_find_organization
  organization = if (id = ENV.fetch("DECIDIM_ORGANIZATION_ID", nil))
                   Decidim::Organization.find_by(id:)
                 elsif (name = ENV.fetch("DECIDIM_ORGANIZATION_NAME", nil))
                   Decidim::Organization.all.detect { |org| org.attributes["name"].values.include?(name) }
                 end

  # 見つからないときは exit code 1 で stderr に出して止める（stdout + 正常終了だと CI から成功と区別できない）。
  unless organization
    abort <<~USAGE
      Organization not found.
      Usage:
        DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:import IN=tmp/bulk/emails.csv
        DECIDIM_ORGANIZATION_NAME=<name> rails bulk_users:import IN=tmp/bulk/emails.csv
    USAGE
  end

  puts "Organization found: id=#{organization.id} name=#{organization.attributes["name"].inspect}"

  organization
end
