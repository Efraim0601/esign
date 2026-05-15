# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendTestWebhookRequestJob do
  describe '#perform' do
    it 'returns when submitter is missing' do
      allow(Submitter).to receive(:find_by).with(id: 1).and_return(nil)
      allow(Faraday).to receive(:post)

      described_class.new.perform('submitter_id' => 1, 'webhook_url_id' => 2)

      expect(Faraday).not_to have_received(:post)
    end

    it 'posts webhook payload with headers and secret' do
      submitter = double('submitter')
      webhook_url = double('webhook_url', url: 'https://example.test/hook', secret: { 'X-Secret' => 'token' })

      allow(Submitter).to receive(:find_by).with(id: 1).and_return(submitter)
      allow(WebhookUrl).to receive(:find_by).with(id: 2).and_return(webhook_url)
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(Submitters::SerializeForWebhook).to receive(:call).with(submitter).and_return({ 'a' => 1 })
      allow(Faraday).to receive(:post)

      described_class.new.perform('submitter_id' => 1, 'webhook_url_id' => 2)

      expect(Faraday).to have_received(:post).with(
        'https://example.test/hook',
        kind_of(String),
        hash_including('Content-Type' => 'application/json', 'User-Agent' => 'FirstSign.com Webhook', 'X-Secret' => 'token')
      )
    end

    it 'raises https error in multitenant mode for non-https urls' do
      submitter = double('submitter')
      webhook_url = double('webhook_url', url: 'http://example.test/hook', secret: {})

      allow(Submitter).to receive(:find_by).with(id: 1).and_return(submitter)
      allow(WebhookUrl).to receive(:find_by).with(id: 2).and_return(webhook_url)
      allow(Docuseal).to receive(:multitenant?).and_return(true)

      expect do
        described_class.new.perform('submitter_id' => 1, 'webhook_url_id' => 2)
      end.to raise_error(SendTestWebhookRequestJob::HttpsError)
    end
  end
end
