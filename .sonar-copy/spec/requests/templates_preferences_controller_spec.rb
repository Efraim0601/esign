# frozen_string_literal: true

describe 'TemplatesPreferencesController' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, preferences: {}) }

  before { sign_in author }

  describe 'GET /templates/:template_id/preferences' do
    it 'returns success' do
      get "/templates/#{template.id}/preferences"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /templates/:template_id/preferences' do
    it 'merges preferences, normalizes booleans and removes blank values' do
      post "/templates/#{template.id}/preferences", params: {
        template: {
          preferences: {
            request_email_subject: 'Please sign',
            request_email_body: '',
            require_email_2fa: 'true'
          }
        }
      }

      expect(response).to have_http_status(:ok)
      prefs = template.reload.preferences
      expect(prefs['request_email_subject']).to eq('Please sign')
      expect(prefs['require_email_2fa']).to be(true)
      expect(prefs).not_to have_key('request_email_body')
    end
  end

  describe 'DELETE /templates/:template_id/preferences' do
    it 'returns ok without deleting when config key is unknown' do
      template.update_column(:preferences, { 'request_email_subject' => 'A' })

      delete "/templates/#{template.id}/preferences", params: { config_key: 'unknown_key' }

      expect(response).to have_http_status(:ok)
      expect(template.reload.preferences['request_email_subject']).to eq('A')
    end

    it 'deletes resettable preference keys for invitation email config' do
      template.update_column(:preferences, {
                               'request_email_subject' => 'A',
                               'request_email_body' => 'B',
                               'submitters' => [{ 'uuid' => 'u1' }],
                               'keep_me' => 'C'
                             })

      delete "/templates/#{template.id}/preferences",
             params: { config_key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY }

      expect(response).to have_http_status(:ok)
      prefs = template.reload.preferences
      expect(prefs).not_to have_key('request_email_subject')
      expect(prefs).not_to have_key('request_email_body')
      expect(prefs).not_to have_key('submitters')
      expect(prefs['keep_me']).to eq('C')
    end
  end
end
