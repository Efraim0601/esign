# frozen_string_literal: true

describe 'TemplatesRestoreController' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user, archived_at: 2.hours.ago) }

  before { sign_in user }

  describe 'POST /templates/:template_id/restore' do
    it 'restores template and enqueues update webhook event' do
      allow(WebhookUrls).to receive(:enqueue_events)

      post "/templates/#{template.id}/restore"

      expect(response).to redirect_to("/templates/#{template.id}")
      expect(template.reload.archived_at).to be_nil
      expect(WebhookUrls).to have_received(:enqueue_events).with(template, 'template.updated')
    end
  end
end
