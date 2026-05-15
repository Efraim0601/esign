# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def invitation_email(user, invited_by: nil)
    @current_account = invited_by&.account || user.account
    @user = user
    @token = @user.send(:set_reset_password_token)

    assign_message_metadata('user_invitation', @user)

    I18n.with_locale(@current_account.locale) do
      mail(to: @user.friendly_name,
           subject: I18n.t('you_are_invited_to_product_name', product_name: Docuseal.product_name))
    end
  end

  def role_changed(user, old_role, new_role, changed_by)
    @user = user
    @old_role = old_role
    @new_role = new_role
    @changed_by = changed_by
    @changed_by_user = User.find_by(id: changed_by)
    @timestamp = Time.current

    mail(
      to: user.email,
      subject: "Vos droits d'accès DocuSeal ont été modifiés"
    )
  end
end
