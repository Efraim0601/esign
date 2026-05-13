# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::SerializeForWebhook do
  describe '.build_submission_status' do
    it 'returns completed when all submitters are completed' do
      s1 = double('s1', completed_at?: true, declined_at?: false)
      s2 = double('s2', completed_at?: true, declined_at?: false)
      submission = double('submission', submitters: [s1, s2], expired?: false)

      expect(described_class.build_submission_status(submission)).to eq('completed')
    end

    it 'returns pending when not completed and not declined and not expired' do
      s1 = double('s1', completed_at?: false, declined_at?: false)
      submission = double('submission', submitters: [s1], expired?: false)

      expect(described_class.build_submission_status(submission)).to eq('pending')
    end
  end

  describe '.fetch_field_value' do
    it 'returns direct value for text-like fields' do
      field = { 'type' => 'text' }

      expect(described_class.fetch_field_value(field, 'hello', {})).to eq('hello')
    end

    it 'maps file field values to proxy urls and removes blanks' do
      blob = double('blob')
      attachment = double('attachment', blob: blob)
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob, expires_at: nil).and_return('url-1')

      field = { 'type' => 'file' }
      urls = described_class.fetch_field_value(field, ['a1', nil, ''], { 'a1' => attachment })

      expect(urls).to eq(['url-1'])
    end
  end
end
