# frozen_string_literal: true

describe 'TemplatesUploadsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /new' do
    it 'returns success' do
      get '/new'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /templates_upload' do
    it 'raises when upload params are invalid in local test env' do
      expect do
        post '/templates_upload'
      end.to raise_error(NoMethodError)
    end
  end
end
