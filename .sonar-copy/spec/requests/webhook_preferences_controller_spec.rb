# frozen_string_literal: true

describe 'WebhookPreferencesController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let!(:webhook_url) { create(:webhook_url, account:, events: %w[form.viewed form.started]) }

  before { sign_in user }

  describe 'PATCH /webhook_preferences/:id' do
    it 'updates selected webhook events' do
      patch "/webhook_preferences/#{webhook_url.id}",
            params: { webhook_url: { events: { 'form.viewed' => '0', 'template.updated' => '1' } } }

      expect(response).to have_http_status(:ok)
      expect(webhook_url.reload.events).to include('form.started', 'template.updated')
      expect(webhook_url.reload.events).not_to include('form.viewed')
    end
  end
end
