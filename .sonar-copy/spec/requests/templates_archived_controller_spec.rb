# frozen_string_literal: true

describe 'TemplatesArchivedController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /templates/archived' do
    it 'returns success' do
      get '/templates/archived'

      expect(response).to have_http_status(:ok)
    end
  end
end
