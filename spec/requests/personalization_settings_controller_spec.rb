# frozen_string_literal: true

describe 'PersonalizationSettingsController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: :admin) }

  before { sign_in admin }

  describe 'GET /settings/personalization' do
    it 'renders the personalization settings page' do
      get '/settings/personalization'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /settings/personalization' do
    it 'creates a new account config with hash value' do
      post '/settings/personalization', params: {
        account_config: {
          key: AccountConfig::FORM_COMPLETED_BUTTON_KEY,
          value: { 'title' => 'Continue', 'url' => 'https://example.test' }
        }
      }

      cfg = account.account_configs.find_by(key: AccountConfig::FORM_COMPLETED_BUTTON_KEY)
      expect(cfg).not_to be_nil
      expect(cfg.value['title']).to eq('Continue')
      expect(response).to have_http_status(:found)
    end

    it 'destroys empty hash account configs' do
      account.account_configs.create!(
        key: AccountConfig::FORM_COMPLETED_BUTTON_KEY,
        value: { 'title' => 'existing' }
      )

      post '/settings/personalization', params: {
        account_config: {
          key: AccountConfig::FORM_COMPLETED_BUTTON_KEY,
          value: { 'title' => '', 'url' => '' }
        }
      }

      expect(account.account_configs.find_by(key: AccountConfig::FORM_COMPLETED_BUTTON_KEY)).to be_nil
    end

    it 'coerces "true"/"false" string values to booleans' do
      post '/settings/personalization', params: {
        account_config: {
          key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
          value: { 'attach_documents' => 'true', 'subject' => 'Hi' }
        }
      }

      cfg = account.account_configs.find_by(key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY)
      expect(cfg.value['attach_documents']).to be(true)
    end

    it 'rejects unknown keys' do
      expect do
        post '/settings/personalization', params: {
          account_config: { key: 'unknown_key', value: 'x' }
        }
      end.to raise_error(PersonalizationSettingsController::InvalidKey)
    end
  end
end
