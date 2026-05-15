# frozen_string_literal: true

describe 'SsoSettingsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  before { sign_in user }

  describe 'GET /settings/sso' do
    it 'loads page successfully' do
      get '/settings/sso'

      expect(response).to have_http_status(:ok)
    end
  end
end
