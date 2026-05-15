# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSubmitterInvitationEmailJob do
  describe '#perform' do
    it 'returns early when submitter is already completed' do
      submitter = double('submitter', completed_at?: true)
      allow(Submitter).to receive(:find).and_return(submitter)

      expect(described_class.new.perform('submitter_id' => 1)).to be_nil
    end

    it 'sends invitation email, records event, and schedules reminders' do
      account = double('account', id: 9)
      submission = double('submission', archived_at?: false, source: 'web')
      submitter = double('submitter', id: 3, account: account, account_id: 9, submission: submission,
                                      template: nil, completed_at?: false, sent_at: nil)
      mail = double('mail')

      allow(Submitter).to receive(:find).with(3).and_return(submitter)
      allow(Accounts).to receive(:can_send_invitation_emails?).with(account).and_return(true)
      allow(SubmitterMailer).to receive(:invitation_email).with(submitter).and_return(mail)
      allow(Submitters::ValidateSending).to receive(:call).with(submitter, mail)
      allow(mail).to receive(:deliver_now!)
      allow(SubmissionEvent).to receive(:create!)
      allow(submitter).to receive(:sent_at=)
      allow(submitter).to receive(:save!)
      allow(AccountConfigs).to receive(:submitter_reminder_offsets).with(account).and_return({ '1d' => 3600 })
      allow(SendSubmitterReminderEmailJob).to receive(:perform_in)

      described_class.new.perform('submitter_id' => 3)

      expect(mail).to have_received(:deliver_now!)
      expect(SubmissionEvent).to have_received(:create!).with(submitter: submitter, event_type: 'send_email')
      expect(submitter).to have_received(:save!)
      expect(SendSubmitterReminderEmailJob).to have_received(:perform_in).with(3600, hash_including('submitter_id' => 3, 'duration_key' => '1d'))
    end
  end
end
