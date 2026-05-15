# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters do
  describe '.normalize_preferences' do
    it 'normalizes booleans and stores email_message_uuid when message is present' do
      account = double('account')
      user = double('user')
      email_message = double('email_message', uuid: 'msg-1')
      params = {
        'message' => { 'subject' => 'Subject', 'body' => 'Body' },
        'send_email' => 'true',
        'send_sms' => '0',
        'require_phone_2fa' => true,
        'require_email_2fa' => 'false',
        'reply_to' => 'reply@example.com',
        'go_to_last' => true
      }

      allow(EmailMessages).to receive(:find_or_create_for_account_user).and_return(email_message)

      result = described_class.normalize_preferences(account, user, params)

      expect(result).to include(
        'email_message_uuid' => 'msg-1',
        'send_email' => true,
        'send_sms' => false,
        'require_phone_2fa' => true,
        'require_email_2fa' => false,
        'reply_to' => 'reply@example.com',
        'go_to_last' => true
      )
    end
  end

  describe '.send_signature_requests' do
    it 'enqueues only eligible submitters and supports delay mode' do
      eligible = double('eligible', id: 1, email: 'a@example.com', declined_at?: false, preferences: {})
      no_email = double('no_email', id: 2, email: nil, declined_at?: false, preferences: {})
      declined = double('declined', id: 3, email: 'b@example.com', declined_at?: true, preferences: {})
      no_send = double('no_send', id: 4, email: 'c@example.com', declined_at?: false, preferences: { 'send_email' => false })

      allow(SendSubmitterInvitationEmailJob).to receive(:perform_async)
      allow(SendSubmitterInvitationEmailJob).to receive(:perform_in)

      described_class.send_signature_requests([eligible, no_email, declined, no_send])
      described_class.send_signature_requests([eligible], delay_seconds: 10)

      expect(SendSubmitterInvitationEmailJob).to have_received(:perform_async).with('submitter_id' => 1).once
      expect(SendSubmitterInvitationEmailJob).to have_received(:perform_in).with(10.seconds, 'submitter_id' => 1).once
    end
  end

  describe '.current_submitter_order?' do
    it 'returns true when all previous submitters are completed' do
      s1 = double('s1', uuid: 'u1', completed_at?: true)
      s2 = double('s2', uuid: 'u2', completed_at?: false)
      submission = double('submission',
                          template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
                          submitters: [s1, s2])
      submitter = double('submitter', uuid: 'u2', submission: submission)

      expect(described_class.current_submitter_order?(submitter)).to be(true)
    end
  end

  describe '.build_document_filename' do
    it 'fills placeholders and appends extension' do
      filename = double('filename', to_s: 'contract.pdf', base: 'contract', extension: 'pdf')
      blob = double('blob', filename: filename)
      submission = double('submission',
                          submitters: [double('s', completed_at?: true)],
                          template_fields: [{ 'type' => 'signature' }])
      account = double('account', timezone: 'UTC')
      submitter = double('submitter', submission: submission, completed_at: Time.current, account: account)
      format = '{document.name} - {submission.status} - {submission.completed_at}'

      allow(ReplaceEmailVariables).to receive(:call).with(format, submitter: submitter).and_return(format)
      allow(I18n).to receive(:l).and_return('2026-05-11 12:00')
      allow(I18n).to receive(:t).with(:signed).and_return('Signed')

      result = described_class.build_document_filename(submitter, blob, format)

      expect(result).to include('contract - Signed - 2026-05-11 12:00.pdf')
    end
  end

  describe '.create_attachment!' do
    it 'raises when file parameter is missing' do
      expect do
        described_class.create_attachment!(double('submitter'), {})
      end.to raise_error(Submitters::ArgumentError, 'file param is missing')
    end

    it 'rejects dangerous file extensions' do
      file = double('file', original_filename: 'malware.exe', content_type: 'application/octet-stream')

      expect do
        described_class.create_attachment!(double('submitter'), { file: file })
      end.to raise_error(Submitters::MaliciousFileExtension, /not allowed/)
    end
  end
end
