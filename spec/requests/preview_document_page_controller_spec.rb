# frozen_string_literal: true

describe 'PreviewDocumentPageController' do
  describe 'GET /preview/:signed_key' do
    it 'returns not found for invalid signed key' do
      get '/preview/invalid-key/1'

      expect(response).to have_http_status(:not_found)
    end
  end
end
