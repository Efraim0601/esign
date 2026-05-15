# frozen_string_literal: true

describe 'EsignSettingsController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }

  before { sign_in admin }

  describe 'GET /settings/esign' do
    it 'renders successfully when no certificates are configured' do
      get '/settings/esign'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /settings/esign' do
    it 'sets AATL cert as default when selected by name' do
      encrypted = create(:encrypted_config, account:, key: EncryptedConfig::ESIGN_CERTS_KEY,
                                            value: { 'custom' => [{ 'name' => 'Old', 'status' => 'default' }] })

      patch '/settings/esign', params: { name: Docuseal::AATL_CERT_NAME }

      expect(response).to redirect_to('/settings/esign')
      encrypted.reload
      expect(encrypted.value['custom'].any? { |e| e['name'] == Docuseal::AATL_CERT_NAME && e['status'] == 'default' }).to be(true)
    end
  end

  describe 'DELETE /settings/esign' do
    it 'removes selected custom certificate entry' do
      encrypted = create(:encrypted_config, account:, key: EncryptedConfig::ESIGN_CERTS_KEY,
                                            value: { 'custom' => [{ 'name' => 'ToRemove', 'status' => 'default' }] })

      delete '/settings/esign', params: { name: 'ToRemove' }

      expect(response).to redirect_to('/settings/esign')
      expect(encrypted.reload.value['custom']).to eq([])
    end
  end
end
