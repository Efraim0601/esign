# frozen_string_literal: true

describe 'ApiSettingsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /settings/api' do
    it 'returns success' do
      get '/settings/api'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /settings/api' do
    it 'rotates token and redirects to api settings page' do
      old_token = user.access_token.token

      post '/settings/api'

      expect(response).to redirect_to('/settings/api')
      expect(user.reload.access_token.token).not_to eq(old_token)
    end
  end
end
