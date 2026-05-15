# frozen_string_literal: true

describe 'TestingApiSettingsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /testing_api_settings' do
    it 'returns success' do
      get '/testing_api_settings'

      expect(response).to have_http_status(:ok)
    end
  end
end
