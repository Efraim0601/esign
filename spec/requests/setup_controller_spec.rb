# frozen_string_literal: true

describe 'SetupController' do
  describe 'GET /setup' do
    it 'renders setup page when no user exists' do
      allow(User).to receive(:exists?).and_return(false)

      get '/setup'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /setup' do
    it 'returns unprocessable when app url is invalid' do
      allow(User).to receive(:exists?).and_return(false)

      post '/setup', params: {
        account: { name: 'Acme', timezone: 'UTC', locale: 'en' },
        user: { first_name: 'Admin', last_name: 'User', email: 'admin@example.test', password: 'password123' },
        encrypted_config: { value: 'not-a-valid-url' }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
