# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::EnsureResultGenerated do
  describe '.call' do
    it 'returns empty array when submitter is nil' do
      expect(described_class.call(nil)).to eq([])
    end

    it 'raises NotCompletedYet when submitter is not completed' do
      submitter = double('submitter', completed_at?: false)

      expect { described_class.call(submitter) }.to raise_error(Submissions::EnsureResultGenerated::NotCompletedYet)
    end

    it 'returns reloaded documents when completion lock already exists' do
      documents = double('documents')
      submitter = double('submitter', id: 7, completed_at?: true, documents: documents)
      allow(documents).to receive(:reload).and_return([:doc])
      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(true)

      expect(described_class.call(submitter)).to eq([:doc])
    end
  end

  describe '.wait_for_complete_or_fail' do
    it 'returns documents when complete event arrives' do
      scope = double('scope')
      last_event = double('event', event_name: 'complete')
      documents = double('documents')
      submitter = double('submitter', id: 3, documents: documents)
      allow(documents).to receive(:reload).and_return([:doc1])

      allow(described_class).to receive(:sleep)
      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:where).and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:last).and_return(last_event)

      expect(described_class.wait_for_complete_or_fail(submitter)).to eq([:doc1])
    end
  end
end
