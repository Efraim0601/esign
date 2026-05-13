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

  describe '.call generation path' do
    it 'creates start lock, calls GenerateAuditTrail, then complete lock' do
      submitter = double('submitter', completed_at?: true)
      submission = double('submission', id: 11, submitters: [submitter])
      scope = double('scope')

      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(false)
      allow(LockEvent).to receive(:where).with(key: 'audit_trail:11').and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:to_a).and_return([])
      allow(LockEvent).to receive(:create!)
      allow(Submissions::GenerateAuditTrail).to receive(:call).with(submission).and_return(:trail)

      expect(described_class.call(submission)).to eq(:trail)
      expect(LockEvent).to have_received(:create!).with(key: 'audit_trail:11', event_name: :start)
      expect(LockEvent).to have_received(:create!).with(key: 'audit_trail:11', event_name: :complete)
    end

    it 'waits for completion when existing events are start/retry' do
      submitter = double('submitter', completed_at?: true)
      submission = double('submission', id: 12, submitters: [submitter])
      scope = double('scope')
      existing_event = double('event', event_name: 'start')

      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(false)
      allow(LockEvent).to receive(:where).with(key: 'audit_trail:12').and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:to_a).and_return([existing_event])
      allow(described_class).to receive(:wait_for_complete_or_fail).with(submission).and_return(:waited)

      expect(described_class.call(submission)).to eq(:waited)
    end

    it 'creates retry event when there are previous completed events but they are not in progress' do
      submitter = double('submitter', completed_at?: true)
      submission = double('submission', id: 13, submitters: [submitter])
      scope = double('scope')
      existing_event = double('event', event_name: 'fail')

      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(false)
      allow(LockEvent).to receive(:where).with(key: 'audit_trail:13').and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:to_a).and_return([existing_event])
      allow(LockEvent).to receive(:create!)
      allow(Submissions::GenerateAuditTrail).to receive(:call).with(submission).and_return(:trail)

      described_class.call(submission)

      expect(LockEvent).to have_received(:create!).with(key: 'audit_trail:13', event_name: :retry)
    end

    it 'logs to Rollbar on StandardError and creates fail lock' do
      submitter = double('submitter', completed_at?: true)
      submission = double('submission', id: 14, submitters: [submitter])
      scope = double('scope')

      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:exists?).and_return(false)
      allow(LockEvent).to receive(:where).with(key: 'audit_trail:14').and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:to_a).and_return([])
      allow(LockEvent).to receive(:create!) do |args|
        raise StandardError, 'pdf-broken' if args[:event_name] == :start
      end
      allow(Rails.logger).to receive(:error)

      expect { described_class.call(submission) }.to raise_error(StandardError, 'pdf-broken')
      expect(LockEvent).to have_received(:create!).with(key: 'audit_trail:14', event_name: :fail)
    end
  end

  describe '.wait_for_complete_or_fail timeout' do
    it 'raises WaitForCompleteTimeout when complete event never arrives' do
      submission = double('submission', id: 99)
      event = double('event', event_name: 'start')
      scope = double('scope')

      allow(described_class).to receive(:sleep) do |_t|
        # advance simulated time so total_wait_time exceeds the timeout immediately
      end
      stub_const('Submissions::EnsureAuditGenerated::CHECK_EVENT_INTERVAL', 100.seconds)
      stub_const('Submissions::EnsureAuditGenerated::CHECK_COMPLETE_TIMEOUT', 1.second)
      allow(ApplicationRecord).to receive(:uncached).and_yield
      allow(LockEvent).to receive(:where).and_return(scope)
      allow(scope).to receive(:order).with(:id).and_return(scope)
      allow(scope).to receive(:last).and_return(event)

      expect do
        described_class.wait_for_complete_or_fail(submission)
      end.to raise_error(Submissions::EnsureAuditGenerated::WaitForCompleteTimeout)
    end
  end
end
