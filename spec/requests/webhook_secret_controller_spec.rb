# frozen_string_literal: true

describe 'WebhookSecretController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let!(:webhook_url) { create(:webhook_url, account:) }

  before { sign_in user }

  describe 'PATCH /webhook_secret/:id' do
    it 'updates webhook secret hash and redirects back to settings webhook page' do
      patch "/webhook_secret/#{webhook_url.id}",
            params: { webhook_url: { secret: { key: 'client_secret', value: 'super-secret' } } }

      expect(response).to redirect_to("/settings/webhooks/#{webhook_url.id}")
      expect(webhook_url.reload.secret).to eq({ 'client_secret' => 'super-secret' })
    end
  end
end
