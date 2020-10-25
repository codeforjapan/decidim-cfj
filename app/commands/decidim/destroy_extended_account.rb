# frozen_string_literal: true

module Decidim
  # This command destroys the user's account.
  class DestroyExtendedAccount < Rectify::Command
    # Destroy a user's account.
    #
    # user - The user to be updated.
    # form - The form with the data.
    def initialize(user, form)
      @user = user
      @form = form
    end

    def call
      return broadcast(:invalid) unless @form.valid?

      Decidim::User.transaction do
        destroy_user_account!
        destroy_user_identities
        destroy_user_group_memberships
        destroy_follows
        destroy_participatory_space_private_user
        delegate_destroy_to_participatory_spaces
        destroy_user_extension
      end

      broadcast(:ok)
    end

    private

    def destroy_user_account!
      @user.name = ""
      @user.nickname = ""
      @user.email = ""
      @user.delete_reason = @form.delete_reason
      @user.admin = false if @user.admin?
      @user.deleted_at = Time.current
      @user.skip_reconfirmation!
      @user.remove_avatar!
      @user.save!
    end

    def destroy_user_identities
      @user.identities.destroy_all
    end

    def destroy_user_group_memberships
      Decidim::UserGroupMembership.where(user: @user).destroy_all
    end

    def destroy_follows
      Decidim::Follow.where(followable: @user).destroy_all
      Decidim::Follow.where(user: @user).destroy_all
    end

    def destroy_participatory_space_private_user
      Decidim::ParticipatorySpacePrivateUser.where(user: @user).destroy_all
    end

    def delegate_destroy_to_participatory_spaces
      Decidim.participatory_space_manifests.each do |space_manifest|
        space_manifest.invoke_on_destroy_account(@user)
      end
    end

    def destroy_user_extension
      user_extension = @user.user_extension
      user_extension.address = ""
      user_extension.gender = nil
      user_extension.birth_year = nil
      user_extension.occupation = ""
    end
  end
end
