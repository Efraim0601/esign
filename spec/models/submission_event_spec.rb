# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmissionEvent do
  describe '#set_submission_id and #set_account_id' do
    it 'copies ids from submitter' do
      submitter = instance_double(Submitter, submission_id: 12, account_id: 34)
      event = described_class.new
      allow(event).to receive(:submitter).and_return(submitter)

      event.send(:set_submission_id)
      event.send(:set_account_id)

      expect(event.submission_id).to eq(12)
      expect(event.account_id).to eq(34)
    end
  end
end
