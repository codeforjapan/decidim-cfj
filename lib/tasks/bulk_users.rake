# frozen_string_literal: true

# CSV から確定ユーザー（メール確認済み・利用規約同意済み）を一括作成する。
# 招待メール・確認メールは送信しない。詳細は docs/BULK_USER_IMPORT.md を参照。
#
# 使い方:
#   DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:import IN=tmp/bulk/emails.csv OUT=tmp/bulk/created.csv
#   DECIDIM_ORGANIZATION_NAME=<name> rails bulk_users:import IN=tmp/bulk/emails.csv
#
# 入力CSV (IN): ヘッダ行の `email` は必須。任意で `name,nickname,password` 列を追加できる。
#   email
#   taro.yamada@example.com
#   hanako@example.com
#
# 出力CSV (OUT, 既定 created_users.csv): email,nickname,name,password,status,error
#   ※ 生成した平文パスワードが入る。配布後は速やかに削除すること。
namespace :bulk_users do
  desc "Create confirmed users in bulk from a CSV (IN= OUT= DECIDIM_ORGANIZATION_ID= or DECIDIM_ORGANIZATION_NAME=)"
  task import: :environment do
    require "csv"

    organization = bulk_users_find_organization
    next unless organization

    abort "組織に利用規約のバージョンが設定されていません。管理画面で利用規約を保存してから再実行してください。" if organization.tos_version.blank?

    input = ENV.fetch("IN")
    output = ENV.fetch("OUT", "created_users.csv")

    rows = CSV.read(input, headers: true, encoding: "bom|utf-8").map do |row|
      { email: row["email"], name: row["name"], nickname: row["nickname"], password: row["password"] }
    end

    puts "Start bulk_users:import of #{rows.count} rows from #{input}"

    importer = Decidim::BulkUserImporter.new(organization:)

    results = CSV.open(output, "w") do |csv|
      csv << %w(email nickname name password status error)
      importer.import(rows) do |result|
        csv << [result.email, result.nickname, result.name, result.password, result.status, result.error]
        csv.flush
      end
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

  unless organization
    puts "Organization not found."
    puts "Usage:"
    puts "  DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:import IN=tmp/bulk/emails.csv OUT=tmp/bulk/created.csv"
    puts "  DECIDIM_ORGANIZATION_NAME=<name> rails bulk_users:import IN=tmp/bulk/emails.csv"
    return
  end

  puts "Organization found: id=#{organization.id} name=#{organization.attributes["name"].inspect}"

  organization
end
