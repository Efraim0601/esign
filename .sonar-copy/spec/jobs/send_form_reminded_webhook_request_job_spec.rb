# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendFormRemindedWebhookRequestJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user) }
  let(:submission) { create(:submission, template: template, created_by_user: user) }
  let(:submitter) do
    create(:submitter, submission: submission, uuid: template.submitters.first['uuid'], completed_at: Time.current)
  end
  let(:webhook_url) { create(:webhook_url, account: account, events: ['form.reminded']) }

  before do
    create(:encrypted_config, key: EncryptedConfig::ESIGN_CERTS_KEY,
                              value: GenerateCertificate.call.transform_values(&:to_pem))
  end

  describe '#perform' do
    around do |example|
      freeze_time { example.run }
    end

    before do
      stub_request(:post, webhook_url.url).to_return(status: 200)
    end

    it 'sends a webhook request with reminder payload' do
      described_class.new.perform('submitter_id' => submitter.id,
                                  'webhook_url_id' => webhook_url.id,
                                  'event_uuid' => SecureRandom.uuid,
                                  'duration_key' => '1d')

      expect(WebMock).to have_requested(:post, webhook_url.url).with(
        body: {
          'event_type' => 'form.reminded',
          'timestamp' => /.*/,
          'data' => JSON.parse(Submitters::SerializeForWebhook.call(submitter.reload).merge(
            'reminder' => { 'duration_key' => '1d' }
          ).to_json)
        },
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => 'AFB.com Webhook'
        }
      ).once
    end

    it 'retries when response status is 400 or higher' do
      stub_request(:post, webhook_url.url).to_return(status: 500)
      event_uuid = SecureRandom.uuid

      expect do
        described_class.new.perform('submitter_id' => submitter.id,
                                    'webhook_url_id' => webhook_url.id,
                                    'event_uuid' => event_uuid,
                                    'duration_key' => '1d')
      end.to change(described_class.jobs, :size).by(1)

      args = described_class.jobs.last['args'].first
      expect(args['attempt']).to eq(1)
      expect(args['last_status']).to eq(500)
      expect(args['duration_key']).to eq('1d')
      expect(args['event_uuid']).to eq(event_uuid)
    end

    it 'returns when submitter is missing' do
      described_class.new.perform('submitter_id' => -1, 'webhook_url_id' => webhook_url.id, 'event_uuid' => SecureRandom.uuid)

      expect(WebMock).not_to have_requested(:post, webhook_url.url)
    end
  end
end
