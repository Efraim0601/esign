# frozen_string_literal: true

RSpec.describe Submissions::EnsureCombinedGenerated do
  describe '.call' do
    it 'returns nil when submitter is nil' do
      expect(described_class.call(nil)).to be_nil
    end

    it 'raises NotCompletedYet when submitter is not completed' do
      submitter = double('submitter', completed_at?: false)
      allow(LockEvent).to receive(:create!)
      allow(Rails.logger).to receive(:error)

      expect { described_class.call(submitter) }.to raise_error(Submissions::EnsureCombinedGenerated::NotCompletedYet)
    end

    it 'returns existing combined attachment when completion lock exists' do
      submission = double('submission', combined_document_attachment: :combined)
      submitter = double('submitter', id: 7, completed_at?: true, submission: submission)

      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(true)

      expect(described_class.call(submitter)).to eq(:combined)
    end
  end

  describe '.wait_for_complete_or_fail' do
    it 'returns combined attachment on complete event' do
      submitter = double('submitter', id: 8, submission: :submission)
      events_relation = double('events_relation')
      last_event = double('event', event_name: 'complete')

      allow(described_class).to receive(:sleep)
      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:where).and_return(events_relation)
      allow(events_relation).to receive(:order).with(:id).and_return(events_relation)
      allow(events_relation).to receive(:last).and_return(last_event)
      allow(ActiveStorage::Attachment).to receive(:find_by).with(record: :submission, name: 'combined_document').and_return(:att)

      expect(described_class.wait_for_complete_or_fail(submitter)).to eq(:att)
    end
  end
end
