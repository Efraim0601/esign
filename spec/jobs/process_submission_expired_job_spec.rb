# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessSubmissionExpiredJob do
  describe '#perform' do
    it 'returns when submission does not exist' do
      allow(Submission).to receive(:find_by).with(id: 1).and_return(nil)
      allow(WebhookUrls).to receive(:enqueue_events)

      described_class.new.perform('submission_id' => 1)

      expect(WebhookUrls).not_to have_received(:enqueue_events)
    end

    it 'enqueues submission.expired event when submission is eligible' do
      not_scope = double('not_scope', exists?: false)
      where_scope = double('where_scope', not: not_scope)
      submitters = double('submitters')
      submission = double('submission', archived_at?: false, template: nil, submitters: submitters)

      allow(Submission).to receive(:find_by).with(id: 2).and_return(submission)
      allow(submitters).to receive(:where).and_return(where_scope)
      allow(submitters).to receive(:exists?).with(completed_at: nil).and_return(true)
      allow(WebhookUrls).to receive(:enqueue_events)

      described_class.new.perform('submission_id' => 2)

      expect(WebhookUrls).to have_received(:enqueue_events).with(submission, 'submission.expired')
    end
  end
end
