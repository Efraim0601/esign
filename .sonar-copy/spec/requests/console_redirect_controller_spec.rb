# frozen_string_literal: true

describe 'ConsoleRedirectController' do
  describe 'GET /upgrade' do
    it 'redirects anonymous users to sign-in with redir param' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      create(:user)

      get '/upgrade'

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to include('/sign_in')
      expect(response.headers['Location']).to include('on_premises')
    end
  end
end
