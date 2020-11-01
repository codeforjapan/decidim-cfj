# frozen_string_literal: true

module Decidim
  # A command with all the business logic to create a user through the sign up form with user_extension data.
  class CreateExtendedRegistration < Rectify::Command
    # Public: Initializes the command.
    #
    # form - A form object with the params.
    def initialize(form)
      @form = form
    end

    # Executes the command. Broadcasts these events:
    #
    # - :ok when everything is valid.
    # - :invalid if the form wasn't valid and we couldn't proceed.
    #
    # Returns nothing.
    def call
      if form.invalid?
        user = User.has_pending_invitations?(form.current_organization.id, form.email)
        user.invite!(user.invited_by) if user
        return broadcast(:invalid)
      end

      transaction do
        create_user
        create_user_extension
      end

      broadcast(:ok, @user)
    rescue ActiveRecord::RecordInvalid
      broadcast(:invalid)
    end

    private

    attr_reader :form

    def create_user
      @user = User.create!(
        email: form.email,
        name: form.name,
        nickname: form.nickname,
        password: form.password,
        password_confirmation: form.password_confirmation,
        organization: form.current_organization,
        tos_agreement: form.tos_agreement,
        newsletter_notifications_at: form.newsletter_at,
        email_on_notification: true,
        accepted_tos_version: form.current_organization.tos_version,
        locale: form.current_locale
      )
    end

    def create_user_extension
      user_extension = form.user_extension
      authorization.attributes = {
        unique_id: user_extension.unique_id,
        metadata: {
          "real_name" => user_extension.real_name,
          "address" => user_extension.address,
          "birth_year" => user_extension.birth_year,
          "gender" => user_extension.gender,
          "occupation" => user_extension.occupation
        }
      }
      authorization.save!
    end

    def authorization
      @authorization ||= Decidim::Authorization.find_or_initialize_by(
        user: @user,
        name: "user_extension"
      )
    end
  end
end
