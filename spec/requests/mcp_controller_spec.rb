# frozen_string_literal: true

describe 'McpController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:, role: :admin) }

  describe 'POST /mcp' do
    it 'returns 401 when no Authorization Bearer token is provided' do
      post '/mcp', params: '{}', headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    context 'with a valid MCP token' do
      let(:raw_token) { SecureRandom.hex(16) }
      let(:sha256) { Digest::SHA256.hexdigest(raw_token) }

      before do
        McpToken.create!(user:, name: 'test', token: raw_token)
        AccountConfig.create!(account:, key: AccountConfig::ENABLE_MCP_KEY, value: true)
      end

      it 'returns 200 OK with empty body for empty raw_post' do
        post '/mcp', params: '',
                     headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:ok)
      end

      it 'returns 400 on parse error' do
        post '/mcp', params: 'not-json{',
                     headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']['message']).to eq('Parse error')
      end

      it 'renders json result when HandleRequest returns a payload' do
        allow(Mcp::HandleRequest).to receive(:call).and_return({ 'result' => 'ok' })

        post '/mcp', params: '{"a":1}',
                     headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({ 'result' => 'ok' })
      end

      it 'returns 202 accepted when HandleRequest returns nil' do
        allow(Mcp::HandleRequest).to receive(:call).and_return(nil)

        post '/mcp', params: '{"a":1}',
                     headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:accepted)
      end

      it 'returns 403 on CanCan::AccessDenied' do
        allow(Mcp::HandleRequest).to receive(:call).and_raise(CanCan::AccessDenied)

        post '/mcp', params: '{"a":1}',
                     headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when MCP is disabled' do
      let(:raw_token) { SecureRandom.hex(16) }
      let(:sha256) { Digest::SHA256.hexdigest(raw_token) }

      before do
        McpToken.create!(user:, name: 'test', token: raw_token)
        allow(Docuseal).to receive(:multitenant?).and_return(false)
      end

      it 'returns 403 when MCP is not enabled in account configs' do
        post '/mcp', params: '{}',
                     headers: { 'CONTENT_TYPE' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
