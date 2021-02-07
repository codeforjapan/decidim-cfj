# frozen_string_literal: true

module Decidim
  # The controller to handle the user's account page.
  class AccountController < Decidim::ApplicationController
    include Decidim::UserProfile

    def show
      enforce_permission_to :show, :user, current_user: current_user
      if need_user_extension?
        @account = form(ExtendedAccountForm).from_model(current_user)
      else
        @account = form(AccountForm).from_model(current_user)
      end
    end

    def update
      enforce_permission_to :update, :user, current_user: current_user
      if need_user_extension?
        @account = form(ExtendedAccountForm).from_params(account_params)
      else
        @account = form(AccountForm).from_params(account_params)
      end

      account_klass = need_user_extension? ? UpdateExtendedAccount : UpdateAccount
      account_klass.call(current_user, @account) do
        on(:ok) do |email_is_unconfirmed|
          flash[:notice] = if email_is_unconfirmed
                             t("account.update.success_with_email_confirmation", scope: "decidim")
                           else
                             t("account.update.success", scope: "decidim")
                           end

          bypass_sign_in(current_user)
          redirect_to account_path
        end

        on(:invalid) do
          flash[:alert] = t("account.update.error", scope: "decidim")
          render action: :show
        end
      end
    end

    def delete
      enforce_permission_to :delete, :user, current_user: current_user
      @form = form(DeleteAccountForm).from_model(current_user)
    end

    def destroy
      enforce_permission_to :delete, :user, current_user: current_user
      @form = form(DeleteAccountForm).from_params(params)

      account_klass = need_user_extension? ? DestroyExtendedAccount : DestroyAccount
      account_klass.call(current_user, @form) do
        on(:ok) do
          sign_out(current_user)
          flash[:notice] = t("account.destroy.success", scope: "decidim")
        end

        on(:invalid) do
          flash[:alert] = t("account.destroy.error", scope: "decidim")
        end
      end

      redirect_to decidim.root_path
    end

    private

    def account_params
      if need_user_extension?
        { avatar: current_user.avatar }.merge(params[:extended_account].to_unsafe_h)
      else
        { avatar: current_user.avatar }.merge(params[:user].to_unsafe_h)
      end
    end

    def need_user_extension?
      current_user.organization&.available_authorization_handlers&.include?("user_extension")
    end
  end
end
