# frozen_string_literal: true

module Decidim
  # 招待メールを経由せず、ログイン可能な確定ユーザーを CSV などから一括作成する。
  #
  #   - email は必須。name / nickname / password は空なら自動生成する。
  #   - 利用規約同意 (accepted_tos_version) とニュースレター受信 (newsletter_notifications_at) をONにする。
  #   - skip_confirmation! で confirmed_at をセットするため、確認メールも招待メールも送信しない。
  #   - nickname の一意化を効かせるため、行ごとに保存する（全体をトランザクションで囲まない）。
  class BulkUserImporter
    CHARSET = (("A".."Z").to_a + ("a".."z").to_a + ("0".."9").to_a).freeze
    MIN_UNIQUE_CHARACTERS = 5

    Result = Struct.new(:email, :nickname, :name, :password, :status, :error, keyword_init: true)

    def initialize(organization:, locale: nil, password_length: 16)
      @organization = organization
      @locale = locale || organization.default_locale
      @password_length = password_length
    end

    # rows: [{ email:, name:?, nickname:?, password:? }, ...]
    # returns: Array<Result> (status: :created / :skipped / :failed)
    def import(rows)
      rows.map do |row|
        result = create_one(row)
        yield result if block_given?
        result
      end
    end

    private

    attr_reader :organization, :locale, :password_length

    def create_one(row)
      email = normalize_email(row[:email])
      return Result.new(email:, status: :skipped, error: "blank email") if email.blank?
      return Result.new(email:, status: :skipped, error: "already exists") if registered?(email)

      create_user(row, email)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(email:, nickname: presence(row[:nickname]), name: presence(row[:name]),
                 status: :failed, error: e.record.errors.full_messages.join("; "))
    rescue StandardError => e
      Result.new(email:, nickname: presence(row[:nickname]), name: presence(row[:name]),
                 status: :failed, error: "#{e.class}: #{e.message}")
    end

    def create_user(row, email)
      attributes = user_attributes(row, email)

      user = Decidim::User.new(attributes)
      user.skip_confirmation! # confirmed_at をセットし、確認メールも送信しない。invite! は呼ばない。
      user.save!

      Result.new(email:, nickname: user.nickname, name: user.name,
                 password: attributes[:password], status: :created)
    end

    def user_attributes(row, email)
      local_part = email.split("@").first
      name = presence(row[:name]) || humanize(local_part)
      nickname = presence(row[:nickname]) || generate_nickname(local_part)
      password = presence(row[:password]) || generate_password(email:, name:, nickname:)

      {
        organization:,
        email:,
        name:,
        nickname:,
        password:,
        password_confirmation: password,
        password_updated_at: Time.current,
        tos_agreement: true,
        accepted_tos_version: organization.tos_version,
        newsletter_notifications_at: Time.current,
        locale:
      }
    end

    def registered?(email)
      Decidim::User.exists?(organization:, email:)
    end

    # nicknamize は DB を照会するため、行ごとに保存していればバッチ内での衝突も連番で解決される。
    def generate_nickname(local_part)
      Decidim::User.nicknamize(local_part, organization.id).presence || "user_#{SecureRandom.hex(4)}"
    end

    # PasswordValidator の制約を満たすランダムパスワードを生成する。
    def generate_password(email:, name:, nickname:)
      forbidden = forbidden_fragments(email:, name:, nickname:)

      loop do
        password = random_password
        return password if acceptable_password?(password, forbidden)
      end
    end

    # PasswordValidator がパスワードへの混入を禁じている文字列。
    # 実際の検証は大文字小文字を区別するが、ここでは小文字化して比較するため常に厳しめに判定される。
    def forbidden_fragments(email:, name:, nickname:)
      local_part, domain = email.split("@")

      fragments = [local_part, nickname, name.delete(" "), organization.host]
      fragments += similar_labels(domain)
      fragments += similar_labels(organization.host)
      fragments += name.split.select { |part| part.length >= similarity_length }

      fragments.compact_blank.map(&:downcase).uniq
    end

    def similar_labels(host)
      host.to_s.split(".").select { |label| label.length >= similarity_length }
    end

    def similarity_length
      Decidim.config.password_similarity_length
    end

    def random_password
      Array.new(password_length) { CHARSET[SecureRandom.rand(CHARSET.size)] }.join
    end

    def acceptable_password?(password, forbidden)
      return false if password.chars.uniq.length < MIN_UNIQUE_CHARACTERS

      downcased = password.downcase
      forbidden.none? { |fragment| downcased.include?(fragment) }
    end

    def humanize(local_part)
      local_part.tr("._+-", " ").split.map(&:capitalize).join(" ").presence || local_part
    end

    def normalize_email(value)
      value.to_s.strip.downcase
    end

    def presence(value)
      value.to_s.strip.presence
    end
  end
end
