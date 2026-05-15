# frozen_string_literal: true

RSpec.describe SendWebhookRequest do
  describe '.create_webhook_event' do
    it 'returns nil when event uuid is blank' do
      webhook_url = double('webhook_url')

      expect(described_class.create_webhook_event(webhook_url, event_uuid: nil, event_type: 'evt', record: double('record'))).to be_nil
    end

    it 'creates or finds webhook event when uuid is present' do
      webhook_url = double('webhook_url', account_id: 7)
      record = double('record')
      relation = double('relation')
      event = double('event')

      allow(WebhookEvent).to receive(:create_with).and_return(relation)
      allow(relation).to receive(:find_or_create_by!).and_return(event)

      result = described_class.create_webhook_event(webhook_url, event_uuid: 'uuid-1', event_type: 'submission.created', record: record)

      expect(result).to eq(event)
      expect(WebhookEvent).to have_received(:create_with).with(hash_including(
        event_type: 'submission.created',
        record: record,
        account_id: 7,
        status: 'pending'
      ))
    end
  end

  describe '.handle_response' do
    it 'stores successful webhook attempt and updates event status' do
      webhook_event = double('webhook_event')
      response = double('response', status: 200, body: 'ok')

      allow(WebhookAttempt).to receive(:create!)
      allow(webhook_event).to receive(:update!)

      result = described_class.handle_response(webhook_event, response: response, attempt: 1)

      expect(result).to eq(response)
      expect(WebhookAttempt).to have_received(:create!).with(hash_including(
        webhook_event: webhook_event,
        response_status_code: 200,
        attempt: 1
      ))
      expect(webhook_event).to have_received(:update!).with(status: 'success')
    end

    it 'stores failed webhook attempt with truncated body and marks event as error' do
      webhook_event = double('webhook_event')
      response = double('response', status: 500, body: 'x' * 300)

      allow(WebhookAttempt).to receive(:create!)
      allow(webhook_event).to receive(:update!)

      described_class.handle_response(webhook_event, response: response, attempt: 2)

      expect(WebhookAttempt).to have_received(:create!).with(hash_including(
        response_status_code: 500,
        attempt: 2
      ))
      expect(webhook_event).to have_received(:update!).with(status: 'error')
    end
  end

  describe '.handle_error' do
    it 'creates webhook attempt with error payload and updates status' do
      webhook_event = double('webhook_event')
      allow(WebhookAttempt).to receive(:create!)
      allow(webhook_event).to receive(:update!)

      result = described_class.handle_error(webhook_event, error_message: 'TimeoutError', attempt: 3)

      expect(result).to be_nil
      expect(WebhookAttempt).to have_received(:create!).with(hash_including(
        webhook_event: webhook_event,
        response_body: 'TimeoutError',
        response_status_code: 0,
        attempt: 3
      ))
      expect(webhook_event).to have_received(:update!).with(status: 'error')
    end

    it 'returns nil when webhook_event is nil' do
      expect(described_class.handle_error(nil, error_message: 'x', attempt: 1)).to be_nil
    end
  end

  describe '.call' do
    it 'returns early on automated retry when event already succeeded' do
      webhook_url = double('webhook_url', url: 'https://example.test/hook', account_id: 1, secret: {})
      webhook_event = double('webhook_event', status: 'success')

      allow(described_class).to receive(:create_webhook_event).and_return(webhook_event)
      allow(Faraday).to receive(:post)

      result = described_class.call(webhook_url, event_uuid: 'evt-1', event_type: 'form.viewed', record: double('record'),
                                                 data: { a: 1 }, attempt: 1)

      expect(result).to be_nil
      expect(Faraday).not_to have_received(:post)
    end

    it 'raises https error for insecure url in multitenant mode' do
      webhook_url = double('webhook_url', url: 'http://example.test/hook', account_id: 1)

      allow(Docuseal).to receive(:multitenant?).and_return(true)
      allow(AccountConfig).to receive(:exists?).and_return(false)

      expect do
        described_class.call(webhook_url, event_uuid: nil, event_type: 'evt', record: double('record'), data: {})
      end.to raise_error(SendWebhookRequest::HttpsError)
    end

    it 'raises localhost error in multitenant mode for localhost targets' do
      webhook_url = double('webhook_url', url: 'https://localhost/hook', account_id: 1)

      allow(Docuseal).to receive(:multitenant?).and_return(true)
      allow(AccountConfig).to receive(:exists?).and_return(false)

      expect do
        described_class.call(webhook_url, event_uuid: nil, event_type: 'evt', record: double('record'), data: {})
      end.to raise_error(SendWebhookRequest::LocalhostError)
    end

    it 'handles Faraday connection errors through handle_error' do
      webhook_url = double('webhook_url', url: 'https://example.test/hook', account_id: 1, secret: {})
      webhook_event = double('webhook_event', status: 'pending')

      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(described_class).to receive(:create_webhook_event).and_return(webhook_event)
      allow(Faraday).to receive(:post).and_raise(Faraday::TimeoutError.new('timeout'))
      allow(described_class).to receive(:handle_error)

      described_class.call(webhook_url, event_uuid: 'evt-2', event_type: 'form.started', record: double('record'),
                                       data: { x: 1 }, attempt: 2)

      expect(described_class).to have_received(:handle_error).with(
        webhook_event,
        attempt: 2,
        error_message: 'TimeoutError'
      )
    end
  end
end
