# frozen_string_literal: true

describe 'Api::UsersController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, first_name: 'Ada', last_name: 'Lovelace', email: 'ada@example.test') }
  let(:access_token) { create(:access_token, user:) }

  describe 'GET /api/user' do
    it 'returns current user payload when token is valid' do
      get '/api/user', headers: { 'X-Auth-Token' => access_token.token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'id' => user.id,
        'first_name' => 'Ada',
        'last_name' => 'Lovelace',
        'email' => 'ada@example.test'
      )
    end
  end
end
