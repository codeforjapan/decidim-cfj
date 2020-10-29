# frozen_string_literal: true

module Decidim
  # This command updates the user's account.
  class UpdateExtendedAccount < Rectify::Command
    # Updates a user's account.
    #
    # user - The user to be updated.
    # form - The form with the data.
    def initialize(user, form)
      @user = user
      @form = form
    end

    def call
      return broadcast(:invalid) unless @form.valid?

      update_personal_data
      update_avatar
      update_password
      update_user_extension

      if @user.valid?
        @user.save!
        notify_followers
        broadcast(:ok, @user.unconfirmed_email.present?)
      else
        @form.errors.add :avatar, @user.errors[:avatar] if @user.errors.has_key? :avatar
        broadcast(:invalid)
      end
    end

    private

    def update_personal_data
      @user.name = @form.name
      @user.nickname = @form.nickname
      @user.email = @form.email
      @user.personal_url = @form.personal_url
      @user.about = @form.about
    end

    def update_avatar
      @user.avatar = @form.avatar
      @user.remove_avatar = @form.remove_avatar
    end

    def update_password
      return if @form.password.blank?

      @user.password = @form.password
      @user.password_confirmation = @form.password_confirmation
    end

    def update_user_extension
      user_extension = @form.user_extension
      authorization.attributes = {
        unique_id: user_extension.unique_id,
        metadata: {
          "real_name" => user_extension.real_name,
          "address" => user_extension.address,
          "birth_year" => user_extension.birth_year,
          "gender" => user_extension.gender,
          "occupation" => user_extension.occupation,
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

    def notify_followers
      return if (@user.previous_changes.keys & %w(about personal_url)).empty?

      Decidim::EventsManager.publish(
        event: "decidim.events.users.profile_updated",
        event_class: Decidim::ProfileUpdatedEvent,
        resource: @user,
        followers: @user.followers
      )
    end
  end
end
