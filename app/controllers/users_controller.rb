# frozen_string_literal: true

class UsersController < ApplicationController
  load_and_authorize_resource :user, only: %i[index edit update destroy reactivate]

  before_action :build_user, only: %i[new create]
  authorize_resource :user, only: %i[new create]

  def index
    @users =
      if params[:status] == 'archived'
        @users.archived.where.not(role: 'integration')
      elsif params[:status] == 'integration'
        @users.active.where(role: 'integration')
      else
        @users.active.where.not(role: 'integration')
      end

    @users = @users.where(role: params[:role]) if params[:role].present?

    @pagy, @users = pagy(@users.preload(account: :account_accesses).where(account: current_account).order(id: :desc))
  end

  def new; end

  def edit
    @role_changes =
      RoleChangeLog.where(user_id: @user.id)
                   .order(created_at: :desc)
                   .limit(20)
                   .includes(:changed_by_user)
  end

  def create
    existing_user = User.accessible_by(current_ability).find_by(email: @user.email)

    if existing_user
      if existing_user.archived_at? &&
         current_ability.can?(:manage, existing_user) && current_ability.can?(:manage, @user.account)
        existing_user.assign_attributes(@user.slice(:first_name, :last_name, :role, :account_id))
        existing_user.archived_at = nil
        @user = existing_user
      else
        @user.errors.add(:email, I18n.t('already_exists'))

        return render turbo_stream: turbo_stream.replace(:modal, template: 'users/new'), status: :unprocessable_content
      end
    end

    @user.password = SecureRandom.hex if @user.password.blank?
    @user.role = User::ADMIN_ROLE unless role_valid?(@user.role)

    if @user.save
      UserMailer.invitation_email(@user).deliver_later!

      redirect_back fallback_location: settings_users_path, notice: I18n.t('user_has_been_invited')
    else
      render turbo_stream: turbo_stream.replace(:modal, template: 'users/new'), status: :unprocessable_content
    end
  end

  def update
    return redirect_to settings_users_path, notice: I18n.t('unable_to_update_user') if Docuseal.demo?

    attrs = user_params.compact_blank
    attrs = attrs.merge(user_params.slice(:archived_at)) if current_ability.can?(:create, @user)

    if params.dig(:user, :account_id).present?
      account = Account.accessible_by(current_ability).find(params.dig(:user, :account_id))

      authorize!(:manage, account)

      @user.account = account
    end

    if @user.update(attrs.except(*(current_user == @user ? %i[password otp_required_for_login role] : %i[password])))
      if @user.saved_change_to_role?
        old_role = @user.role_before_last_save
        new_role = @user.role

        RoleChangeLog.create!(
          changed_by: current_user.id,
          user_id: @user.id,
          old_role:,
          new_role:,
          changed_at: Time.current
        )

        begin
          UserMailer.role_changed(@user, old_role, new_role, current_user.id).deliver_later
        rescue StandardError => e
          Rails.logger.error("[UserRoleChange] Unable to enqueue role_changed email: #{e.class}: #{e.message}")
        end

        @user.increment!(:permission_version)

        # Devise :rememberable uses remember_created_at; clearing it tightens remembered sessions.
        @user.forget_me!
      end

      if @user.try(:pending_reconfirmation?) && @user.previous_changes.key?(:unconfirmed_email)
        SendConfirmationInstructionsJob.perform_async('user_id' => @user.id)

        redirect_back fallback_location: settings_users_path,
                      notice: I18n.t('a_confirmation_email_has_been_sent_to_the_new_email_address')
      else
        redirect_back fallback_location: settings_users_path, notice: I18n.t('user_has_been_updated')
      end
    else
      render turbo_stream: turbo_stream.replace(:modal, template: 'users/edit'), status: :unprocessable_content
    end
  end

  def destroy
    if Docuseal.demo? || @user.id == current_user.id
      return redirect_to settings_users_path, notice: I18n.t('unable_to_remove_user')
    end

    @user.update!(archived_at: Time.current)

    redirect_back fallback_location: settings_users_path, notice: I18n.t('user_has_been_removed')
  end

  def reactivate
    @user.update!(archived_at: nil)

    redirect_back fallback_location: settings_users_path, notice: I18n.t('user_has_been_reactivated')
  end

  private

  def role_valid?(role)
    User::ROLES.include?(role)
  end

  def build_user
    @user = current_account.users.new(user_params)
  end

  def user_params
    if params.key?(:user)
      permitted_params = %i[email first_name last_name password archived_at otp_required_for_login]

      permitted_params << :role if role_valid?(params.dig(:user, :role))

      params.require(:user).permit(permitted_params)
    else
      {}
    end
  end
end
