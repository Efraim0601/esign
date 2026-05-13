# frozen_string_literal: true

describe 'SmsSettingsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /settings/sms' do
    it 'returns success' do
      get '/settings/sms'

      expect(response).to have_http_status(:ok)
    end
  end
end
