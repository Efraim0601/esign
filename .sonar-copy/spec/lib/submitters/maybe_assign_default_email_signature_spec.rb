# frozen_string_literal: true

RSpec.describe Submitters::MaybeAssignDefaultEmailSignature do
  describe '.call' do
    it 'returns early when tracking param does not match' do
      submitter = double('submitter')
      allow(SubmissionEvents).to receive(:build_tracking_param).and_return('expected')

      result = described_class.call(submitter, { t: 'unexpected' }, [])

      expect(result).to be_nil
    end

    it 'creates default signature attachment when previous exists' do
      relation = double('relation')
      signature_attachment = double('signature_attachment', blob_id: 9)
      submitter = double('submitter', id: 1, attachments_attachments: relation)
      params = { t: 'ok' }

      allow(SubmissionEvents).to receive(:build_tracking_param).and_return('ok')
      allow(described_class).to receive(:find_previous_signature).with(submitter).and_return(signature_attachment)
      allow(relation).to receive(:create_or_find_by!)

      described_class.call(submitter, params, [])

      expect(relation).to have_received(:create_or_find_by!).with(blob_id: 9)
    end
  end

  describe '.find_previous_signature' do
    it 'returns nil when submitter email is blank' do
      submitter = double('submitter', email: nil)

      expect(described_class.find_previous_signature(submitter)).to be_nil
    end
  end
end
