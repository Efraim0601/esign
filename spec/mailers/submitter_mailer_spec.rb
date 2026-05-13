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

  describe '#invitation_email' do
    it 'builds invitation email using configured subject/body' do
      account = double('account', locale: 'en')
      template = double('template', preferences: {}, submitters: [])
      submission = double('submission', account: account, created_by_user: nil, template: template, source: 'web')
      submitter = double(
        'submitter',
        id: 5,
        uuid: 'u1',
        preferences: {},
        account: double('submitter_account', email_messages: double(find_by: nil)),
        submission: submission,
        friendly_name: 'to@example.test',
        template: template,
        email: 'to@example.test'
      )
      creator = double('creator', id: 9, friendly_name: 'from@example.test', email: 'from@example.test')
      allow(submission).to receive(:created_by_user).and_return(creator)
      allow(template).to receive(:author).and_return(creator)
      allow(AccountConfigs).to receive(:find_for_account).and_return(double('cfg', value: { 'subject' => 'Subj', 'body' => 'Body' }))
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'to@example.test', subject: 'Subj'))
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered subject')

      message = mailer.invitation_email(submitter)

      expect(message).to be_a(Mail::Message)
      expect(ReplaceEmailVariables).to have_received(:call)
    end
  end

  describe '#declined_email' do
    it 'normalizes integration recipient plus-tag in declined notification' do
      account = double('account', locale: 'en')
      creator = double('creator', id: 3, friendly_name: 'creator@example.test', email: 'creator@example.test')
      template = double('template', name: 'Contract', author: creator)
      submission = double('submission', account: account, name: 'Deal', template: template, source: 'web',
                                        created_by_user: creator)
      submitter = double('submitter', submission: submission, friendly_name: 'sig@example.test',
                                      name: 'Signer', email: 'sig@example.test', phone: nil)
      integration_user = double('user', role: 'integration', friendly_name: 'bot+tag@example.test')
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'bot@example.test', subject: 'Declined'))
      allow(I18n).to receive(:t).and_call_original

      message = mailer.declined_email(submitter, integration_user)

      expect(message).to be_a(Mail::Message)
    end
  end

  describe '#documents_copy_email' do
    it 'builds copy email and computes signed link when sig is true' do
      account = double('account', locale: 'en')
      template = double('template', preferences: {})
      submission = double('submission', account: account, template: template, source: 'web')
      submitter = double('submitter', submission: submission, template: template, signed_id: 'signed-token',
                                      friendly_name: 'sig@example.test', email: 'sig@example.test',
                                      preferences: {}, account_id: 1)
      creator = double('creator', id: 7, friendly_name: 'from@example.test', email: 'from@example.test')
      allow(submission).to receive(:created_by_user).and_return(creator)
      allow(template).to receive(:author).and_return(creator)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(AccountConfigs).to receive(:find_for_account).and_return(nil)
      allow(mailer).to receive(:add_completed_email_attachments!).and_return([])
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'sig@example.test', subject: 'Copy'))
      allow(I18n).to receive(:t).with(:your_document_copy).and_return('Your copy')

      message = mailer.documents_copy_email(submitter, sig: true)

      expect(message).to be_a(Mail::Message)
      expect(mailer.instance_variable_get(:@sig)).to eq('signed-token')
    end
  end

  describe '#invitation_reminder_email' do
    it 'builds reminder using reminder config when present' do
      account = double('account', locale: 'en')
      template = double('template', preferences: {})
      submission = double('submission', account: account, created_by_user: nil, template: template, source: 'web')
      submitter = double(
        'submitter',
        id: 5,
        uuid: 'u1',
        preferences: {},
        account: double('submitter_account', email_messages: double(find_by: nil)),
        submission: submission,
        friendly_name: 'to@example.test',
        template: template,
        email: 'to@example.test',
        account_id: 1
      )
      creator = double('creator', id: 9, friendly_name: 'from@example.test', email: 'from@example.test')
      allow(submission).to receive(:created_by_user).and_return(creator)
      allow(template).to receive(:author).and_return(creator)
      allow(AccountConfigs).to receive(:find_for_account)
        .with(account, AccountConfig::SUBMITTER_INVITATION_REMINDER_EMAIL_KEY)
        .and_return(double('cfg', value: { 'subject' => 'Reminder Subject', 'body' => 'Reminder Body' }))
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'to@example.test', subject: 'Reminder Subject'))
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered subject')

      message = mailer.invitation_reminder_email(submitter)

      expect(message).to be_a(Mail::Message)
    end

    it 'falls back to invitation email config when reminder is absent' do
      account = double('account', locale: 'en')
      template = double('template', preferences: { 'invitation_reminder_email_subject' => nil })
      submission = double('submission', account: account, created_by_user: nil, template: template, source: 'web')
      submitter = double(
        'submitter',
        id: 5, uuid: 'u1', preferences: {},
        account: double('submitter_account', email_messages: double(find_by: nil)),
        submission: submission,
        friendly_name: 'to@example.test',
        template: template, email: 'to@example.test', account_id: 1
      )
      creator = double('creator', id: 9, friendly_name: 'from@example.test', email: 'from@example.test')
      allow(submission).to receive(:created_by_user).and_return(creator)
      allow(template).to receive(:author).and_return(creator)
      allow(AccountConfigs).to receive(:find_for_account)
        .with(account, AccountConfig::SUBMITTER_INVITATION_REMINDER_EMAIL_KEY).and_return(nil)
      allow(AccountConfigs).to receive(:find_for_account)
        .with(account, AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY)
        .and_return(double('cfg', value: { 'subject' => 'Fallback Subj', 'body' => 'Fallback' }))
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'to@example.test', subject: 'Fallback Subj'))
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered subject')

      message = mailer.invitation_reminder_email(submitter)

      expect(message).to be_a(Mail::Message)
    end
  end

  describe '#completed_email' do
    it 'builds completed notification email with attachments' do
      account = double('account', locale: 'en')
      template = double('template', preferences: {}, name: 'Contract')
      submission = double('submission', account: account, template: template, source: 'web',
                                        name: 'Doc', created_by_user: nil)
      submitter = double('submitter', submission: submission, account: account, account_id: 1)
      user = double('user', role: 'admin', friendly_name: 'admin@example.test')
      creator = double('creator', id: 9, friendly_name: 'from@example.test')
      allow(submission).to receive(:created_by_user).and_return(creator)
      allow(template).to receive(:author).and_return(creator)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(AccountConfigs).to receive(:find_for_account).and_return(double('cfg', value: { 'subject' => 'Done', 'body' => 'Body', 'attach_documents' => false, 'attach_audit_log' => false }))
      allow(mailer).to receive(:add_completed_email_attachments!).and_return([])
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'admin@example.test', subject: 'Done'))
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered')

      message = mailer.completed_email(submitter, user)

      expect(message).to be_a(Mail::Message)
    end

    it 'uses to override when provided' do
      account = double('account', locale: 'en')
      template = double('template', preferences: {}, name: 'Contract')
      submission = double('submission', account: account, template: template, source: 'web',
                                        name: 'Doc', created_by_user: nil)
      submitter = double('submitter', submission: submission, account: account, account_id: 1)
      user = double('user', role: 'admin', friendly_name: 'admin@example.test')
      creator = double('creator', id: 9, friendly_name: 'from@example.test')
      allow(submission).to receive(:created_by_user).and_return(creator)
      allow(template).to receive(:author).and_return(creator)
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(AccountConfigs).to receive(:find_for_account).and_return(nil)
      allow(mailer).to receive(:add_completed_email_attachments!).and_return([])
      allow(mailer).to receive(:assign_message_metadata)
      allow(mailer).to receive(:put_metadata)
      allow(mailer).to receive(:mail).and_return(Mail.new(to: 'other@example.test', subject: 'Done'))
      allow(ReplaceEmailVariables).to receive(:call).and_return('Rendered')
      allow(I18n).to receive(:t).with(:template_name_has_been_completed_by_submitters).and_return('Default subj')

      message = mailer.completed_email(submitter, user, to: 'other@example.test')

      expect(message).to be_a(Mail::Message)
    end
  end
end
