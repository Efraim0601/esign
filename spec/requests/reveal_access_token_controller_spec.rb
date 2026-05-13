# frozen_string_literal: true

describe 'RevealAccessTokenController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, password: 'password') }

  before { sign_in user }

  describe 'GET /settings/reveal_access_token' do
    it 'returns success' do
      get '/settings/reveal_access_token'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /settings/reveal_access_token' do
    it 'returns unprocessable content when password is invalid' do
      post '/settings/reveal_access_token', params: { password: 'wrong-password' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
