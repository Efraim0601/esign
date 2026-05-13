# frozen_string_literal: true

describe 'WebhookSettingsController' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account:, role: User::ADMIN_ROLE) }
  let!(:webhook_url) { create(:webhook_url, account:, url: 'https://hooks.example.test/a') }

  before { sign_in admin }

  describe 'GET /settings/webhooks' do
    it 'renders show/index successfully' do
      get '/settings/webhooks'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /settings/webhooks/:id/resend' do
    it 'enqueues test webhook when completed submitter exists' do
      template = create(:template, account:, author: admin)
      submission = create(:submission, :with_submitters, template:, created_by_user: admin)
      submission.submitters.first.update!(completed_at: Time.current)
      allow(SendTestWebhookRequestJob).to receive(:perform_async)

      post "/settings/webhooks/#{webhook_url.id}/resend"

      expect(response).to redirect_to('/settings/webhooks')
      expect(SendTestWebhookRequestJob).to have_received(:perform_async)
    end
  end
end
