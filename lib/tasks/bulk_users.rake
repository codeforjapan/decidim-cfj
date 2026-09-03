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
# 出力CSVは運用者が Excel で開いて配布に使う。BOM が無いと日本語（name 列、発行タスクの
# フリガナ列）が文字化けするため、入力側の "bom|utf-8" と対で出力にも付ける。
BULK_USERS_UTF8_BOM = "\xEF\xBB\xBF"

namespace :bulk_users do
  desc "Create confirmed users in bulk from a CSV (IN= OUT= DECIDIM_ORGANIZATION_ID= or DECIDIM_ORGANIZATION_NAME=)"
  task import: :environment do
    require "csv"

    organization = bulk_users_find_organization

    abort "組織に利用規約のバージョンが設定されていません。管理画面で利用規約を保存してから再実行してください。" if organization.tos_version.blank?

    input = ENV.fetch("IN")
    output = ENV.fetch("OUT") { "tmp/bulk_users/created_users_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.csv" }

    table = CSV.read(input, headers: true, encoding: "bom|utf-8")

    # ヘッダ名が違う（Excel が書き出す "Email"、日本語見出し、ヘッダ行なし等）と全行が
    # blank email で skip され、created=0 skipped=N failed=0 を出して exit 0 で正常終了して
    # しまう。組織未検出や出力先の重複では中断するのに、入力の取り違えだけ無言で no-op に
    # なるのは非対称なので、ここで弾く。
    #
    # 出力ファイルを作る前に検証する。作ってしまうと、CSV を直して同じ OUT で再実行しようと
    # しても「既に存在する」で中断され、別パスの指定を強いられるため。
    unless table.headers.include?("email")
      abort "入力CSV #{input} に email 列がありません（検出した列: #{table.headers.compact.join(", ").presence || "なし"}）。" \
            "1行目をヘッダ行にして email 列を用意してください。"
    end

    rows = table.map do |row|
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
      io.write(BULK_USERS_UTF8_BOM)
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

  # 参加スペース単位の匿名アカウント発行。詳細は docs/BULK_SPACE_ACCOUNTS.md を参照。
  #
  # 使い方:
  #   DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:issue IN=tmp/bulk/plan.csv DRY_RUN=1  # 採番の事前確認
  #   DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:issue IN=tmp/bulk/plan.csv            # 実行
  #
  # 入力CSV (IN): space_type,space_slug,role,count
  #   assemblies,a-high,participant,40
  #   assemblies,a-high,admin,3
  desc "Issue anonymous per-space accounts from an instruction CSV (IN= OUT= DRY_RUN=1)"
  task issue: :environment do
    require "csv"

    organization = bulk_users_find_organization

    settings = Decidim::BulkUserImportSetting.find_by(decidim_organization_id: organization.id)
    unless settings&.enabled?
      abort "この組織では一括アカウント発行が有効になっていません。" \
            "bulk_users:configure ENABLED=true EMAIL_DOMAIN=<ドメイン> で設定してください。"
    end
    abort "email_domain が設定されていません。bulk_users:configure EMAIL_DOMAIN=<ドメイン> で設定してください。" if settings.email_domain.blank?
    abort "組織に利用規約のバージョンが設定されていません。管理画面で利用規約を保存してから再実行してください。" if organization.tos_version.blank?

    dry_run = ENV["DRY_RUN"].present?
    input = ENV.fetch("IN")

    instructions = CSV.read(input, headers: true, encoding: "bom|utf-8").map do |row|
      { space_type: row["space_type"], space_slug: row["space_slug"], role: row["role"], count: row["count"] }
    end

    issuer = Decidim::BulkSpaceAccountIssuer.new(organization:, email_domain: settings.email_domain, dry_run:)

    # 出力ファイルを作る前に指示を検証する（不正があれば何も作らず exit 1）。
    begin
      issuer.validate!(instructions)
    rescue ArgumentError => e
      abort e.message
    end

    if dry_run
      puts "DRY RUN: 何も作成しません。採番と生成されるIDだけを表示します。"
      results = issuer.issue(instructions) do |result|
        puts "  #{result.space_slug} #{result.role} #{result.account_id} #{result.email}"
      end
      puts "planned=#{results.count}"
      next
    end

    puts "Start bulk_users:issue of #{instructions.count} instructions from #{input}"

    output = ENV.fetch("OUT") { "tmp/bulk_users/issued_accounts_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.csv" }
    FileUtils.mkdir_p(File.dirname(output))

    # bulk_users:import と同じ方針: 出力は発行済みパスワードの唯一の記録なので、
    # O_EXCL + 0600 で新規作成し、既存ファイルがあれば書き込まずに中断する。
    io = begin
      File.open(output, File::CREAT | File::EXCL | File::WRONLY, 0o600)
    rescue Errno::EEXIST
      abort "出力先 #{output} は既に存在するため中断しました。発行済みパスワードを守るため上書きはしません。別のパスを OUT= で指定してください。"
    end

    results = begin
      io.write(BULK_USERS_UTF8_BOM)
      csv = CSV.new(io)
      csv << %w(space_slug role account_id email password furigana status error)
      issuer.issue(instructions) do |result|
        csv << [result.space_slug, result.role, result.account_id, result.email,
                result.password, result.furigana, result.status, result.error]
        io.flush
      end
    ensure
      io.close
    end

    tally = results.group_by(&:status).transform_values(&:count)
    puts "created=#{tally[:created].to_i} failed=#{tally[:failed].to_i}"
    puts "認証情報を #{output} に出力しました。平文パスワードを含むため取り扱いに注意してください。"

    results.select { |result| result.status == :failed }.each do |result|
      warn "  FAILED #{result.account_id}: #{result.error}"
    end

    puts "Finish bulk_users:issue"
  end

  # 組織ごとの発行設定の確認・変更。/system の画面から編集できるようにするまでの暫定手段。
  #
  #   DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:configure                              # 現在値の表示
  #   DECIDIM_ORGANIZATION_ID=<id> rails bulk_users:configure ENABLED=true EMAIL_DOMAIN=chiba-mirai.test
  desc "Show or update bulk account issuing settings (EMAIL_DOMAIN= ENABLED=true|false)"
  task configure: :environment do
    organization = bulk_users_find_organization

    settings = Decidim::BulkUserImportSetting.find_or_initialize_by(decidim_organization_id: organization.id)
    settings.email_domain = ENV["EMAIL_DOMAIN"] if ENV["EMAIL_DOMAIN"]
    settings.enabled = ActiveModel::Type::Boolean.new.cast(ENV["ENABLED"]) unless ENV["ENABLED"].nil?

    if settings.changed?
      begin
        settings.save!
        puts "設定を更新しました。"
      rescue ActiveRecord::RecordInvalid => e
        abort "設定を保存できません: #{e.record.errors.full_messages.join("; ")}"
      end
    end

    puts "organization=#{organization.id} enabled=#{settings.enabled} email_domain=#{settings.email_domain.inspect}"
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
