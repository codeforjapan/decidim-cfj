# frozen_string_literal: true

module Decidim
  # A one-time code emailed to a user who enters the admin panel.
  # Only the digest is stored; a user has at most one row, which also keeps
  # the count of wrong codes and the lock of the admin panel.
  class AdminLoginCode < ApplicationRecord
    self.table_name = "decidim_cfj_admin_login_codes"

    CODE_LENGTH = 6
    EXPIRES_IN = 10.minutes
    RESEND_INTERVAL = 1.minute
    # Wrong codes allowed for one code.
    MAX_FAILED_ATTEMPTS = 3
    # Wrong codes allowed in total until a correct one is entered. Reaching it locks the admin panel
    # until a system admin unlocks it.
    MAX_TOTAL_FAILED_ATTEMPTS = 10

    belongs_to :user,
               class_name: "Decidim::User",
               foreign_key: :decidim_user_id,
               inverse_of: false

    def self.enabled?
      Rails.application.secrets.dig(:decidim, :admin_login_code, :enabled).present?
    end

    # Replaces the user's code with a new one and returns the plain code.
    #
    # Returns nil when the admin panel is locked or the resend interval has not passed.
    # The row is locked while deciding, so that concurrent requests (a double-clicked
    # send button, several tabs) do not each issue a code.
    def self.issue!(user)
      code = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
      issued = transaction do
        record = find_by(user:) || create_or_find_by!(user:)
        record.lock!
        next false if record.locked?
        next false unless record.resendable?

        record.update!(code_digest: digest(user, code), sent_at: Time.current, failed_attempts: 0)
        true
      end
      code if issued
    end

    def self.unlock!(user)
      where(user:).update_all(code_digest: nil, sent_at: nil, failed_attempts: 0, total_failed_attempts: 0, locked_at: nil) # rubocop:disable Rails/SkipsModelValidations
    end

    def self.digest(user, code)
      key = Rails.application.key_generator.generate_key("decidim_cfj admin login code")
      OpenSSL::HMAC.hexdigest("SHA256", key, "#{user.id}:#{code}")
    end

    def locked?
      locked_at.present?
    end

    def expired?
      sent_at.nil? || sent_at < EXPIRES_IN.ago
    end

    def exhausted?
      failed_attempts >= MAX_FAILED_ATTEMPTS
    end

    def usable?
      code_digest.present? && !expired? && !exhausted? && !locked?
    end

    def resendable?
      sent_at.nil? || sent_at < RESEND_INTERVAL.ago
    end

    # Returns true and consumes the code when it matches.
    # An attempt is counted before comparing so that concurrent requests
    # cannot exceed the limits.
    def verify(code)
      return false if expired?

      counted = self.class.where(id:, locked_at: nil)
                    .where.not(code_digest: nil)
                    .where(failed_attempts: ...MAX_FAILED_ATTEMPTS)
                    .update_all("failed_attempts = failed_attempts + 1, total_failed_attempts = total_failed_attempts + 1") # rubocop:disable Rails/SkipsModelValidations
      return false if counted.zero?

      current_digest = self.class.where(id:).pick(:code_digest)
      return false if current_digest.nil?
      return false unless ActiveSupport::SecurityUtils.secure_compare(current_digest, self.class.digest(user, code.to_s))

      self.class.where(id:, code_digest: current_digest, locked_at: nil)
          .update_all(code_digest: nil, sent_at: nil, failed_attempts: 0, total_failed_attempts: 0) == 1 # rubocop:disable Rails/SkipsModelValidations
    end

    # Locks the admin panel when the total of wrong codes has reached the limit.
    # Returns true only for the call that locked it.
    def lock_if_exhausted!
      self.class.where(id:, locked_at: nil)
          .where(total_failed_attempts: MAX_TOTAL_FAILED_ATTEMPTS..)
          .update_all(locked_at: Time.current) == 1 # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
