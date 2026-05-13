# frozen_string_literal: true

describe 'NewslettersController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /newsletter' do
    it 'returns success' do
      get '/newsletter'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /newsletter' do
    it 'posts payload and redirects to root path' do
      allow(Faraday).to receive(:post)

      patch '/newsletter', params: { user: { email: 'person@example.test' } }

      expect(response).to redirect_to('/')
      expect(Faraday).to have_received(:post)
    end
  end
end
