# frozen_string_literal: true

describe 'UsersSendResetPasswordController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:) }
  let(:target_user) { create(:user, account:) }

  before { sign_in admin }

  describe 'PATCH /users/:user_id/send_reset_password' do
    it 'sends reset instructions when outside cooldown window' do
      allow_any_instance_of(User).to receive(:send_reset_password_instructions)
      target_user.update_column(:reset_password_sent_at, 2.days.ago)

      patch "/users/#{target_user.id}/send_reset_password"

      expect(response).to redirect_to('/settings/users')
    end

    it 'does not resend during cooldown window' do
      expect_any_instance_of(User).not_to receive(:send_reset_password_instructions)
      target_user.update_column(:reset_password_sent_at, 1.minute.ago)

      patch "/users/#{target_user.id}/send_reset_password"

      expect(response).to redirect_to('/settings/users')
    end
  end
end
