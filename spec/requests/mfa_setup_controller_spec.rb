# frozen_string_literal: true

describe 'MfaSetupController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: :admin) }

  before { sign_in user }

  describe 'GET /mfa_setup/new' do
    it 'sets otp_secret and provisioning url for the current user' do
      get '/mfa_setup/new'

      expect(response).to have_http_status(:ok)
      expect(user.reload.otp_secret).not_to be_nil
    end

    it 'redirects with alert when 2FA is already configured' do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)

      get '/mfa_setup/new'

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).not_to be_blank
    end
  end

  describe 'GET /mfa_setup' do
    it 'renders show page' do
      get '/mfa_setup'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /mfa_setup/edit' do
    it 'renders edit modal' do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)

      get '/mfa_setup/edit'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /mfa_setup' do
    it 'activates 2FA when OTP is valid' do
      user.update!(otp_secret: User.generate_otp_secret)
      allow_any_instance_of(User).to receive(:validate_and_consume_otp!).and_return(true)

      post '/mfa_setup', params: { otp_attempt: '123456' }

      expect(user.reload.otp_required_for_login).to be(true)
      expect(response).to redirect_to(settings_profile_index_path)
    end

    it 'returns unprocessable when OTP is invalid' do
      user.update!(otp_secret: User.generate_otp_secret)
      allow_any_instance_of(User).to receive(:validate_and_consume_otp!).and_return(false)

      post '/mfa_setup', params: { otp_attempt: 'wrong' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.otp_required_for_login).to be_falsey
    end
  end

  describe 'DELETE /mfa_setup' do
    it 'disables 2FA when OTP is valid' do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      allow_any_instance_of(User).to receive(:validate_and_consume_otp!).and_return(true)

      delete '/mfa_setup', params: { otp_attempt: '123456' }

      expect(user.reload.otp_required_for_login).to be(false)
      expect(user.reload.otp_secret).to be_nil
      expect(response).to redirect_to(settings_profile_index_path)
    end

    it 'returns unprocessable when OTP is invalid' do
      user.update!(otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      allow_any_instance_of(User).to receive(:validate_and_consume_otp!).and_return(false)

      delete '/mfa_setup', params: { otp_attempt: 'wrong' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.otp_required_for_login).to be(true)
    end
  end
end
