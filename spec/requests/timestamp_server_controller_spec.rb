# frozen_string_literal: true

describe 'TimestampServerController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: :admin) }

  before { sign_in admin }

  describe 'POST /timestamp_server' do
    it 'returns not found in multitenant mode' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)

      post '/timestamp_server', params: { encrypted_config: { value: 'https://tsa.example.test' } }

      expect(response).to have_http_status(:not_found)
    end

    it 'deletes existing config when blank value is submitted' do
      create(:encrypted_config, account:, key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY,
                                value: 'https://old-tsa.example.test')

      post '/timestamp_server', params: { encrypted_config: { value: '' } }

      expect(EncryptedConfig.find_by(account:, key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY)).to be_nil
      expect(response).to be_redirect
    end

    it 'rescues SocketError raised by Faraday and redirects with alert' do
      allow(Faraday).to receive(:new).and_raise(SocketError.new('no host'))

      post '/timestamp_server', params: { encrypted_config: { value: 'https://tsa.example.test/tsa' } }

      expect(response).to be_redirect
    end

    it 'redirects with notice when timeserver test passes' do
      stub_request(:post, /tsa\.example/).to_return(status: 200, body: 'OK')

      post '/timestamp_server', params: { encrypted_config: { value: 'https://tsa.example.test/tsa' } }

      expect(response).to be_redirect
    end

    it 'redirects with alert when timeserver returns non-200' do
      stub_request(:post, /tsa\.example/).to_return(status: 500, body: '')

      post '/timestamp_server', params: { encrypted_config: { value: 'https://tsa.example.test/tsa' } }

      expect(response).to be_redirect
      expect(flash[:alert]).not_to be_blank
    end
  end
end
