# frozen_string_literal: true

RSpec.describe SubmitterMailer do
  subject(:mailer) { described_class.new }

  describe '#normalize_user_email' do
    it 'removes plus tag for integration users' do
      user = double('user', role: 'integration', friendly_name: 'bot+tag@example.com')

      expect(mailer.send(:normalize_user_email, user)).to eq('bot@example.com')
    end

    it 'keeps friendly name for regular users' do
      user = double('user', role: 'admin', friendly_name: 'admin@example.com')

      expect(mailer.send(:normalize_user_email, user)).to eq('admin@example.com')
    end
  end

  describe '#build_submitter_reply_to' do
    it 'returns nil for no-reply addresses' do
      submitter = double(
        'submitter',
        preferences: { 'reply_to' => 'no-reply@example.com' },
        template: double(preferences: {}, author: double(email: 'author@example.com')),
        submission: double(created_by_user: nil),
        email: 'submitter@example.com'
      )

      expect(mailer.send(:build_submitter_reply_to, submitter)).to be_nil
    end

    it 'falls back to creator email when no explicit reply_to' do
      creator = double('creator', email: 'creator@example.com', friendly_name: 'creator+ops@example.com')
      submitter = double(
        'submitter',
        preferences: {},
        template: double(preferences: {}, author: creator),
        submission: double(created_by_user: creator),
        email: 'submitter@example.com'
      )

      expect(mailer.send(:build_submitter_reply_to, submitter)).to eq('creator@example.com')
    end

    it 'uses documents copy reply_to from template preferences' do
      submitter = double(
        'submitter',
        preferences: {},
        template: double(preferences: { 'documents_copy_email_reply_to' => 'docs@example.test' },
                         author: double(email: 'author@example.test')),
        submission: double(created_by_user: nil),
        email: 'submitter@example.test'
      )

      reply_to = mailer.send(:build_submitter_reply_to, submitter, documents_copy_email: true)

      expect(reply_to).to eq('docs@example.test')
    end

    it 'uses email config reply_to when present' do
      submitter = double(
        'submitter',
        preferences: {},
        template: double(preferences: {}, author: double(email: 'author@example.test')),
        submission: double(created_by_user: nil),
        email: 'submitter@example.test'
      )
      email_config = double('email_config', value: { 'reply_to' => 'config@example.test' })

      reply_to = mailer.send(:build_submitter_reply_to, submitter, email_config: email_config)

      expect(reply_to).to eq('config@example.test')
    end
  end

  describe '#build_invite_subject' do
    it 'uses custom subject when provided' do
      submitter = double('submitter')
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered subject')

      result = mailer.send(:build_invite_subject, 'Hi {{name}}', nil, submitter)

      expect(result).to eq('Rendered subject')
    end

    it 'uses localized fallback key based on signature fields' do
      submission = double('submission', name: 'Doc Name', template: double(name: 'Template Name'))
      submitter = double('submitter', with_signature_fields?: true, submission: submission)
      allow(I18n).to receive(:t).and_return('Localized subject')

      result = mailer.send(:build_invite_subject, nil, nil, submitter)

      expect(result).to eq('Localized subject')
      expect(I18n).to have_received(:t).with(:you_have_been_invited_to_sign_the_name, name: 'Doc Name')
    end

    it 'uses email config subject when subject is nil' do
      submitter = double('submitter')
      email_config = double('email_config', value: { 'subject' => 'Config subject' })
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered from config')

      result = mailer.send(:build_invite_subject, nil, email_config, submitter)

      expect(result).to eq('Rendered from config')
      expect(ReplaceEmailVariables).to have_received(:call).with('Config subject', submitter: submitter)
    end
  end

  describe '#add_attachments_with_size_limit' do
    it 'adds attachments until size threshold is reached' do
      submitter = double('submitter')
      blob1 = double('blob1')
      blob2 = double('blob2')
      a1 = double('a1', byte_size: 1000, blob: blob1, download: 'data1')
      a2 = double('a2', byte_size: SubmitterMailer::MAX_ATTACHMENTS_SIZE, blob: blob2, download: 'data2')
      allow(Submitters).to receive(:build_document_filename).and_return('file.pdf')

      total = mailer.send(:add_attachments_with_size_limit, submitter, [a1, a2], 0)

      expect(total).to be >= SubmitterMailer::MAX_ATTACHMENTS_SIZE
      expect(mailer.attachments['file.pdf']).not_to be_nil
    end
  end

  describe '#fetch_config_email_body' do
    it 'returns nil when config is absent' do
      expect(mailer.send(:fetch_config_email_body, nil)).to be_nil
    end

    it 'returns configured body when present' do
      config = double('config', value: { 'body' => 'Hello' })
      expect(mailer.send(:fetch_config_email_body, config)).to eq('Hello')
    end
  end

  describe '#build_submitter_preferences_index' do
    it 'indexes template submitter preferences by uuid' do
      template = double('template', preferences: { 'submitters' => [{ 'uuid' => 'u1', 'x' => 1 }] })
      submitter = double('submitter', template: template)

      index = mailer.send(:build_submitter_preferences_index, submitter)

      expect(index['u1']['x']).to eq(1)
    end
  end

  describe '#from_address_for_submitter' do
    it 'uses integration_from_email for api/embed source' do
      account = double('account')
      source_submission = double('submission', source: 'api')
      user = double('user', id: 11)
      submitter = double('submitter', submission: source_submission, account: account)
      allow(AccountConfig).to receive(:find_by).and_return(double(value: 'integration@example.com'))
      users_assoc = double('users_assoc')
      allow(account).to receive(:users).and_return(users_assoc)
      allow(users_assoc).to receive(:find_by).with(email: 'integration@example.com').and_return(user)
      allow(mailer).to receive(:put_metadata)

      from = mailer.send(:from_address_for_submitter, submitter)

      expect(from).to eq('integration@example.com')
      expect(mailer).to have_received(:put_metadata).with('from_user_id' => 11)
    end

    it 'falls back to submission creator friendly_name for regular source' do
      creator = double('creator', id: 22, friendly_name: 'creator@example.com')
      submission = double('submission', source: 'web', created_by_user: creator, template: double(author: creator))
      submitter = double('submitter', submission: submission, account: double('account'))
      allow(mailer).to receive(:put_metadata)

      from = mailer.send(:from_address_for_submitter, submitter)

      expect(from).to eq('creator@example.com')
      expect(mailer).to have_received(:put_metadata).with('from_user_id' => 22)
    end
  end

  describe '#maybe_set_custom_domain' do
    it 'sets @custom_domain in multitenant mode with account config' do
      submitter = double('submitter', account_id: 44)
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      allow(AccountConfig).to receive(:find_by).and_return(double(value: 'custom.example.test'))

      mailer.send(:maybe_set_custom_domain, submitter)

      expect(mailer.instance_variable_get(:@custom_domain)).to eq('custom.example.test')
    end

    it 'does not set custom domain outside multitenant mode' do
      submitter = double('submitter', account_id: 44)
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(AccountConfig).to receive(:find_by)

      mailer.send(:maybe_set_custom_domain, submitter)

      expect(mailer.instance_variable_get(:@custom_domain)).to be_nil
      expect(AccountConfig).not_to have_received(:find_by)
    end
  end

  describe '#otp_verification_email' do
    it 'builds verification email and stores generated otp' do
      account = double('account', locale: 'en')
      submitter = double('submitter', id: 10, email: 'user@example.test', slug: 'sub-1', account: account)
      message = Mail.new(to: 'user@example.test', subject: 'Email verification')
      allow(EmailVerificationCodes).to receive(:generate).and_return('123456')
      allow(I18n).to receive(:t).with('email_verification').and_return('Email verification')
      allow(mailer).to receive(:mail).and_return(message)

      result = mailer.otp_verification_email(submitter)

      expect(EmailVerificationCodes).to have_received(:generate).with('user@example.test:sub-1')
      expect(result).to eq(message)
      expect(mailer.instance_variable_get(:@otp_code)).to eq('123456')
    end
  end
end
