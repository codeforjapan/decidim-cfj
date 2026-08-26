# frozen_string_literal: true

module Decidim
  # 参加スペース単位で、匿名IDの確定アカウントを一括発行する。
  # 学校現場など、参加者の実メールアドレスを収集しない運用を想定している。
  # 詳細は docs/BULK_SPACE_ACCOUNTS.md を参照。
  #
  #   - アカウントID（= nickname = 表示名 = メールのローカル部）は
  #     参加者: <slug>-<連番3桁> / 管理者: <slug>-a<連番3桁>
  #   - メールアドレスは実在しないドメイン（組織ごとの設定 email_domain）で生成する
  #   - パスワードは BulkUserImporter に可読性優先の文字種（PASSWORD_CHARSET）で生成させる
  #   - 管理者にもプライベートユーザー登録を行う。ロール（AssemblyUserRole）は管理画面への
  #     アクセス権であって参加権ではなく、can_participate? は private_users しか見ないため、
  #     登録しないと「管理者なのに自分のスペースに入れない」状態になる
  #   - ユーザー作成とスペース登録は1アカウントずつトランザクションで束ね、途中で失敗したら
  #     そのアカウントごと巻き戻す（ユーザーだけ作られてスペースに入れない状態を残さない）
  class BulkSpaceAccountIssuer
    class ImportFailed < StandardError; end

    SPACE_TYPES = {
      "assemblies" => {
        space_class_name: "Decidim::Assembly",
        role_class_name: "Decidim::AssemblyUserRole",
        space_foreign_key: :assembly
      }
      # 将来 participatory_processes に対応する場合はここに追加する
    }.freeze
    ROLES = %w(participant admin).freeze
    ROLE_MARKERS = { "participant" => "", "admin" => "a" }.freeze

    PASSWORD_LENGTH = 10
    # 大文字英字と数字のみ（紙面配布・読み上げ・手入力を想定）。O/0・I/1/L の見間違いと、
    # Q（キュー）/ 9（キュウ）の読み上げ衝突を避けるため I O Q 0 1 を除いた31文字。
    PASSWORD_CHARSET = "ABCDEFGHJKLMNPRSTUVWXYZ23456789".chars.freeze

    # 各文字のカタカナ読み。数字は通常読み。配布物の「フリガナ」列に使う。
    FURIGANA = {
      "A" => "エー", "B" => "ビー", "C" => "シー", "D" => "ディー", "E" => "イー",
      "F" => "エフ", "G" => "ジー", "H" => "エイチ", "J" => "ジェー", "K" => "ケー",
      "L" => "エル", "M" => "エム", "N" => "エヌ", "P" => "ピー", "R" => "アール",
      "S" => "エス", "T" => "ティー", "U" => "ユー", "V" => "ブイ", "W" => "ダブリュー",
      "X" => "エックス", "Y" => "ワイ", "Z" => "ゼット",
      "2" => "ニ", "3" => "サン", "4" => "ヨン", "5" => "ゴ", "6" => "ロク",
      "7" => "ナナ", "8" => "ハチ", "9" => "キュウ"
    }.freeze

    # nickname の上限20文字から、管理者形式の "-a" + 連番3桁の5文字を引いた値。
    # 超える slug は切り詰めず、実行前にエラーで止める（切り詰めると別スペースと衝突し得るため）。
    MAX_SLUG_LENGTH = 15
    SEQUENCE_DIGITS = 3

    Result = Struct.new(:space_slug, :role, :account_id, :email, :password, :furigana, :status, :error, keyword_init: true)

    Instruction = Struct.new(:space_type, :space_slug, :role, :amount, keyword_init: true) do
      # slug は大文字を許容するが nickname は小文字のみのため、ID の接頭辞は小文字化する
      def prefix = space_slug.to_s.downcase
    end

    def initialize(organization:, email_domain:, dry_run: false)
      raise ArgumentError, "email_domain is blank" if email_domain.blank?

      @organization = organization
      @email_domain = email_domain
      @dry_run = dry_run
      # dry_run は採番の計算だけでインポータを使わないため作らない
      # （tos_version 未設定の組織でも、プレビュー表示は失敗させない）。
      return if dry_run

      @importer = BulkUserImporter.new(organization:,
                                       password_length: PASSWORD_LENGTH,
                                       password_charset: PASSWORD_CHARSET)
    end

    # instructions: [{ space_type:, space_slug:, role:, count: }, ...]
    # 1件でも不正があれば ArgumentError で何も作らずに止める（部分実行で欠番だけ残るのを防ぐ）。
    def validate!(instructions)
      errors = normalize(instructions).each_with_index.flat_map do |instruction, index|
        instruction_errors(instruction, index)
      end

      raise ArgumentError, "invalid instructions:\n  #{errors.join("\n  ")}" if errors.any?
    end

    # ブロックを渡すと1アカウント処理するたびに Result を yield する（rake が逐次書き出すため）。
    # dry_run の場合は何も作成せず、採番と生成されるIDだけを status: :planned で返す。
    def issue(instructions, &block)
      validate!(instructions)

      normalize(instructions).flat_map { |instruction| issue_instruction(instruction, &block) }
    end

    private

    attr_reader :organization, :email_domain, :dry_run, :importer

    def normalize(instructions)
      instructions.map do |raw|
        Instruction.new(
          space_type: raw[:space_type].to_s.strip,
          space_slug: raw[:space_slug].to_s.strip,
          role: raw[:role].to_s.strip.presence || "participant",
          amount: raw[:count].to_s.strip.to_i
        )
      end
    end

    def instruction_errors(instruction, index)
      line = "row #{index + 1} (#{instruction.space_slug.presence || "?"})"
      errors = []
      errors << "#{line}: unknown space_type #{instruction.space_type.inspect}" unless SPACE_TYPES.has_key?(instruction.space_type)
      errors << "#{line}: unknown role #{instruction.role.inspect} (use #{ROLES.join(" / ")})" unless ROLES.include?(instruction.role)
      errors << "#{line}: count must be a positive integer" unless instruction.amount.positive?

      if instruction.prefix.length > MAX_SLUG_LENGTH
        errors << "#{line}: slug is longer than #{MAX_SLUG_LENGTH} characters " \
                  "(nickname limit is 20; shorten the space slug instead of truncating)"
      elsif SPACE_TYPES.has_key?(instruction.space_type) && find_space(instruction).nil?
        errors << "#{line}: #{instruction.space_type} with slug #{instruction.space_slug.inspect} not found in this organization"
      end

      errors
    end

    def find_space(instruction)
      config = SPACE_TYPES.fetch(instruction.space_type)
      config[:space_class_name].constantize.find_by(organization:, slug: instruction.space_slug)
    end

    def issue_instruction(instruction, &block)
      space = find_space(instruction)
      sequence = next_sequence(instruction)

      Array.new(instruction.amount) do |offset|
        result = issue_one(instruction, space, sequence + offset)
        block&.call(result)
        result
      end
    end

    # 既存の同形式ニックネームの最大連番の次から採番する。
    # failed で消費された番号（欠番）は再利用しない（運用上許容する判断）。
    def next_sequence(instruction)
      prefix = "#{instruction.prefix}-#{ROLE_MARKERS.fetch(instruction.role)}"
      pattern = /\A#{Regexp.escape(prefix)}(\d+)\z/

      # 参加者の LIKE には管理者形式（...-a001）も引っかかるため、正規表現側で数字のみに絞る。
      # nickname は組織内で UserBaseEntity（ユーザー+グループ）全体で一意なので、そちらを走査する。
      existing = Decidim::UserBaseEntity
                 .where(decidim_organization_id: organization.id)
                 .where("nickname LIKE ?", "#{Decidim::UserBaseEntity.sanitize_sql_like(prefix)}%")
                 .pluck(:nickname)

      (existing.filter_map { |nickname| nickname[pattern, 1]&.to_i }.max || 0) + 1
    end

    def build_account_id(instruction, sequence)
      "#{instruction.prefix}-#{ROLE_MARKERS.fetch(instruction.role)}#{sequence.to_s.rjust(SEQUENCE_DIGITS, "0")}"
    end

    def issue_one(instruction, space, sequence)
      account_id = build_account_id(instruction, sequence)
      email = "#{account_id}@#{email_domain}"
      base = { space_slug: instruction.space_slug, role: instruction.role, account_id:, email: }

      return Result.new(**base, status: :planned) if dry_run

      import_result = nil
      ActiveRecord::Base.transaction do
        import_result = importer.import([{ email:, name: account_id, nickname: account_id }]).first
        raise ImportFailed, import_result.error.to_s unless import_result.status == :created

        link_space(space, instruction, Decidim::User.find_by!(organization:, email:))
      end

      Result.new(**base,
                 password: import_result.password,
                 furigana: furigana_for(import_result.password),
                 status: :created)
    rescue ImportFailed => e
      Result.new(**base, status: :failed, error: e.message)
    rescue StandardError => e
      Result.new(**base, status: :failed, error: "#{e.class}: #{e.message}")
    end

    def link_space(space, instruction, user)
      # published: false のため公開メンバー一覧には載らない。can_participate? には影響しない。
      Decidim::ParticipatorySpacePrivateUser.create!(user:, privatable_to: space, published: false) if space.private_space?

      return unless instruction.role == "admin"

      config = SPACE_TYPES.fetch(instruction.space_type)
      config[:role_class_name].constantize.create!(:user => user, :role => "admin",
                                                   config[:space_foreign_key] => space)
      # 既存の管理者追加フロー（ParticipatorySpace::CreateAdmin）に合わせて自分のスペースを
      # フォローさせる。通知メールは notifications_sending_frequency = "none" のため送られない。
      Decidim::Follow.create!(followable: space, user:)
    end

    def furigana_for(password)
      password.chars.map { |char| FURIGANA.fetch(char) }.join("・")
    end
  end
end
