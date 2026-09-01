# frozen_string_literal: true

module Decidim
  # 招待メールを経由せず、ログイン可能な確定ユーザーを CSV などから一括作成する。
  #
  #   - email は必須。name / nickname / password は空なら自動生成する。
  #   - 利用規約同意 (accepted_tos_version) をONにする。
  #   - ニュースレター受信 (newsletter_notifications_at) は設定しない。各自が設定画面でONにする。
  #   - 通知ダイジェスト (notifications_sending_frequency) は "none" にする。受信できない
  #     アドレスで登録する運用があり、既定の daily のままだと通知が溜まり始めた時点から
  #     毎日バウンスし続けるため。受信を希望する本人が設定画面で変更する。
  #   - skip_confirmation! で confirmed_at をセットするため、確認メールも招待メールも送信しない。
  #   - nickname の一意化を効かせるため、行ごとに保存する（全体をトランザクションで囲まない）。
  class BulkUserImporter
    CHARSET = (("A".."Z").to_a + ("a".."z").to_a + ("0".."9").to_a).freeze
    MIN_UNIQUE_CHARACTERS = 5
    # 禁止フラグメントとの衝突は稀で、通常は1回で確定する。ここに達するのは password_charset と
    # 拒否リストの組み合わせが破綻しているときだけなので、無限に引き直さず行を failed にして知らせる。
    MAX_PASSWORD_ATTEMPTS = 1_000

    Result = Struct.new(:email, :nickname, :name, :password, :status, :error, keyword_init: true)

    def initialize(organization:, locale: nil, password_length: 16, password_charset: CHARSET)
      # tos_version が無いまま作ると全ユーザーが「規約未同意」になり、ログインのたびに同意画面へ
      # 誘導される。呼び出し側（rake / 管理画面）の検証漏れをここで最終的に止める。
      raise ArgumentError, "organization has a blank tos_version" if organization.tos_version.blank?
      raise ArgumentError, "password_length must be at least #{::PasswordValidator::MINIMUM_LENGTH}" if password_length < ::PasswordValidator::MINIMUM_LENGTH

      charset = password_charset.is_a?(String) ? password_charset.chars : password_charset.to_a
      raise ArgumentError, "password_charset needs at least #{MIN_UNIQUE_CHARACTERS} distinct characters" if charset.uniq.size < MIN_UNIQUE_CHARACTERS

      @organization = organization
      @locale = locale || organization.default_locale
      @password_length = password_length
      @password_charset = charset.freeze
    end

    # rows: [{ email:, name:?, nickname:?, password:? }, ...]
    # ブロックを渡すと、1行処理するたびに Result を yield する。
    # 呼び出し側はその都度書き出すことで、途中で中断しても処理済み分の認証情報を残せる。
    # returns: Array<Result> (status: :created / :skipped / :failed)
    def import(rows)
      rows.map do |row|
        result = create_one(row)
        yield result if block_given?
        result
      end
    end

    private

    attr_reader :organization, :locale, :password_length, :password_charset

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
        # 既定の daily のままだと、通知が溜まり始めた時点から毎日ダイジェストが送信される。
        # 実在しないアドレスだとバウンスが蓄積して送信基盤全体を止めかねないため、明示的に切る。
        notifications_sending_frequency: "none",
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

      MAX_PASSWORD_ATTEMPTS.times do
        password = random_password
        return password if acceptable_password?(password, forbidden)
      end

      raise "could not generate an acceptable password in #{MAX_PASSWORD_ATTEMPTS} attempts"
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
      Array.new(password_length) { password_charset[SecureRandom.rand(password_charset.size)] }.join
    end

    def acceptable_password?(password, forbidden)
      return false if password.chars.uniq.length < MIN_UNIQUE_CHARACTERS
      return false if common_password?(password)
      return false if denied_password?(password)

      downcased = password.downcase
      forbidden.none? { |fragment| downcased.include?(fragment) }
    end

    # PasswordValidator の password_too_common? と同じ判定。保存時に弾かれて行が failed に
    # なる前に、生成時に検出して引き直す。
    def common_password?(password)
      Decidim::CommonPasswords.instance.passwords.include?(password)
    end

    # PasswordValidator の denied? と同じ判定（Decidim.denied_passwords は文字列と Regexp が混在し得る）。
    def denied_password?(password)
      Array(Decidim.denied_passwords).any? do |expression|
        expression.is_a?(Regexp) ? password.match?(expression) : expression.to_s == password
      end
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
