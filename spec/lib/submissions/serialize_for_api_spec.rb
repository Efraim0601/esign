# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::SerializeForApi do
  describe '.build_status' do
    it 'returns declined when any submitter declined' do
      submission = double('submission', expired?: false)
      submitter = double('submitter', declined_at?: true)

      expect(described_class.build_status(submission, [submitter])).to eq('declined')
    end

    it 'returns expired when pending submitters and submission expired' do
      submission = double('submission', expired?: true)
      submitter = double('submitter', declined_at?: false)

      expect(described_class.build_status(submission, [submitter])).to eq('expired')
    end
  end

  describe '.maybe_build_combined_url' do
    it 'returns nil when not all submitters are completed' do
      submitter = double('submitter', completed_at?: false)
      submission = double('submission')

      expect(described_class.maybe_build_combined_url([submitter], submission, {})).to be_nil
    end

    it 'builds proxy url from existing attachment' do
      completed = double('submitter', completed_at?: true, completed_at: Time.current)
      blob = double('blob')
      attachment = double('attachment', blob: blob)
      submission = double('submission', combined_document_attachment: attachment)

      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob, expires_at: nil).and_return('proxy-url')

      expect(described_class.maybe_build_combined_url([completed], submission, {})).to eq('proxy-url')
    end
  end
end
