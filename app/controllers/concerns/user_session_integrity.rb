# frozen_string_literal: true

# Bumps to +permission_version+ on a user (e.g. role change) invalidate open browser sessions
# so permissions are re-established after sign-in.
module UserSessionIntegrity
  extend ActiveSupport::Concern

  private

  def enforce_user_session_permission_version!
    if session[:impersonated_user_id].present?
      sync_impersonated_permission_version!
      return if performed?
    end

    sync_true_user_permission_version!
  end

  def sync_impersonated_permission_version!
    imp = User.find_by(uuid: session[:impersonated_user_id])
    if imp.nil?
      stop_impersonating_user
      session.delete(:impersonated_permission_version)

      return
    end

    expected = imp.permission_version
    stored = session[:impersonated_permission_version]

    if stored.nil?
      session[:impersonated_permission_version] = expected
    elsif stored != expected
      stop_impersonating_user
      session.delete(:impersonated_permission_version)
      redirect_to root_path, alert: I18n.t('your_session_was_refreshed_please_continue')
    end
  end

  def sync_true_user_permission_version!
    u = true_user
    return if u.blank?

    expected = u.permission_version
    stored = session[:user_permission_version]

    if stored.nil?
      session[:user_permission_version] = expected
    elsif stored != expected
      sign_out(u)
      session.delete(:user_permission_version)
      session.delete(:impersonated_permission_version)
      redirect_to new_user_session_path, alert: I18n.t('your_session_was_refreshed_sign_in_again')
    end
  end
end
