# frozen_string_literal: true

RSpec.describe WebhookUrls do
  let(:account) { create(:account) }

  describe '.for_account_id' do
    it 'returns webhooks subscribed to the event in multitenant mode', multitenant: true do
      webhook = create(:webhook_url, account:, events: ['form.completed'])
      create(:webhook_url, account:, events: ['form.viewed'])

      result = described_class.for_account_id(account.id, 'form.completed')

      expect(result.to_a).to eq([webhook])
    end

    it 'matches multiple events when an array is passed', multitenant: true do
      webhook_a = create(:webhook_url, account:, events: ['form.completed'])
      webhook_b = create(:webhook_url, account:, events: ['form.viewed'])
      create(:webhook_url, account:, events: ['submission.created'])

      result = described_class.for_account_id(account.id, %w[form.completed form.viewed])

      expect(result.to_a).to contain_exactly(webhook_a, webhook_b)
    end

    it 'returns empty when no webhooks subscribe to the event', multitenant: true do
      create(:webhook_url, account:, events: ['form.viewed'])

      result = described_class.for_account_id(account.id, 'form.completed')

      expect(result.to_a).to eq([])
    end
  end

  describe '.enqueue_events' do
    let(:submitter) { create(:submission, :with_submitters, template: create(:template, account:)).submitters.first }

    it 'pushes a webhook job for each subscribed url', multitenant: true do
      create(:webhook_url, account:, events: ['form.viewed'])
      create(:webhook_url, account:, events: ['form.viewed'])
      create(:webhook_url, account:, events: ['form.completed']) # not subscribed

      expect do
        described_class.enqueue_events(submitter, 'form.viewed')
      end.to change(SendFormViewedWebhookRequestJob.jobs, :size).by(2)
    end

    it 'enqueues nothing when no webhooks subscribe', multitenant: true do
      create(:webhook_url, account:, events: ['form.viewed'])

      expect do
        described_class.enqueue_events(submitter, 'form.completed')
      end.not_to change(SendFormCompletedWebhookRequestJob.jobs, :size)
    end

    it 'raises KeyError for unknown event prefixes' do
      expect do
        described_class.enqueue_events(submitter, 'unknown.thing')
      end.to raise_error(KeyError)
    end
  end
end
