# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::EnsureAuditGenerated do
  describe '.call' do
    it 'returns nil when submission is nil' do
      expect(described_class.call(nil)).to be_nil
    end

    it 'raises NotCompletedYet when not all submitters are completed' do
      submitter = double('submitter', completed_at?: false)
      submission = double('submission', submitters: [submitter])

      expect { described_class.call(submission) }.to raise_error(Submissions::EnsureAuditGenerated::NotCompletedYet)
    end

    it 'returns existing audit trail attachment when complete lock exists' do
      submitter = double('submitter', completed_at?: true)
      attachment = double('attachment')
      submission = double('submission', id: 9, submitters: [submitter], audit_trail_attachment: attachment)

      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(true)

      expect(described_class.call(submission)).to eq(attachment)
    end
  end

  describe '.wait_for_complete_or_fail' do
    it 'returns audit attachment on complete event' do
      submission = double('submission', id: 5)
      event = double('event', event_name: 'complete')
      scope = double('scope')
      attachment = double('attachment')

      allow(described_class).to receive(:sleep)
      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:where).and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:last).and_return(event)
      allow(ActiveStorage::Attachment).to receive(:find_by).with(record: submission, name: 'audit_trail').and_return(attachment)

      expect(described_class.wait_for_complete_or_fail(submission)).to eq(attachment)
    end
  end
end
