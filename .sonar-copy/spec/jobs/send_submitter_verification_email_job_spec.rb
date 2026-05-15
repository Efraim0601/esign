# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSubmitterVerificationEmailJob do
  describe '#perform' do
    it 'sends otp verification email and records 2fa event' do
      account = double('account', locale: 'fr')
      submitter = double('submitter', account: account, email: 'user@example.test')
      mail = double('mail')

      allow(Submitter).to receive(:find).with(8).and_return(submitter)
      allow(SubmitterMailer).to receive(:otp_verification_email).with(submitter, locale: 'fr').and_return(mail)
      allow(mail).to receive(:deliver_now!)
      allow(SubmissionEvent).to receive(:create!)

      described_class.new.perform('submitter_id' => 8, 'locale' => nil)

      expect(mail).to have_received(:deliver_now!)
      expect(SubmissionEvent).to have_received(:create!).with(
        submitter_id: 8,
        event_type: 'send_2fa_email',
        data: { email: 'user@example.test' }
      )
    end
  end
end
