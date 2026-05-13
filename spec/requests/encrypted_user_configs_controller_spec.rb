# frozen_string_literal: true

describe 'EncryptedUserConfigsController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let!(:config) { EncryptedUserConfig.create!(user:, key: 'api_key', value: { 'value' => 'abc' }) }

  before { sign_in user }

  describe 'DELETE /encrypted_user_configs/:id' do
    it 'destroys encrypted user config and redirects back fallback' do
      expect do
        delete "/encrypted_user_configs/#{config.id}"
      end.to change(EncryptedUserConfig, :count).by(-1)

      expect(response).to redirect_to('/')
    end
  end
end
