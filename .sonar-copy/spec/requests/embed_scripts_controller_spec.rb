# frozen_string_literal: true

describe 'EmbedScriptsController' do
  describe 'GET /js/:filename' do
    it 'returns javascript content' do
      get '/js/embed.js'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('application/javascript')
      expect(response.body).to include('docuseal-builder')
    end
  end
end
