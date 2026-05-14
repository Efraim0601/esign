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


  describe 'GET /settings/esign/new' do
    it 'renders new certificate form' do
      get '/settings/esign/new'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /settings/esign re-promotes custom cert' do
    it 'promotes a named custom cert to default and demotes the previous default' do
      encrypted = create(:encrypted_config, account:, key: EncryptedConfig::ESIGN_CERTS_KEY,
                                            value: { 'custom' => [
                                              { 'name' => 'A', 'status' => 'default' },
                                              { 'name' => 'B', 'status' => 'validate' }
                                            ] })

      patch '/settings/esign', params: { name: 'B' }

      encrypted.reload
      expect(encrypted.value['custom'].find { |e| e['name'] == 'A' }['status']).to eq('validate')
      expect(encrypted.value['custom'].find { |e| e['name'] == 'B' }['status']).to eq('default')
    end
  end

  describe 'POST /settings/esign duplicate cert name' do
    it 'rejects when name already exists in custom list' do
      create(:encrypted_config, account:, key: EncryptedConfig::ESIGN_CERTS_KEY,
                                value: { 'custom' => [{ 'name' => 'My Cert' }] })

      post '/settings/esign',
           params: { esign_settings_controller_cert_form_record: { name: 'My Cert', password: 'x' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects when name equals reserved default cert name' do
      post '/settings/esign',
           params: { esign_settings_controller_cert_form_record: {
             name: EsignSettingsController::DEFAULT_CERT_NAME, password: 'x'
           } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
