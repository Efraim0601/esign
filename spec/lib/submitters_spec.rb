# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters do
  describe '.search' do
    it 'uses fulltext search when enabled' do
      relation = double('relation')
      allow(Docuseal).to receive(:fulltext_search?).and_return(true)
      allow(described_class).to receive(:fulltext_search).and_return(:fulltext_scope)

      result = described_class.search(double('user'), relation, 'john')

      expect(result).to eq(:fulltext_scope)
      expect(described_class).to have_received(:fulltext_search)
    end

    it 'uses plain search when fulltext is disabled' do
      relation = double('relation')
      allow(Docuseal).to receive(:fulltext_search?).and_return(false)
      allow(described_class).to receive(:plain_search).and_return(:plain_scope)

      result = described_class.search(double('user'), relation, 'john')

      expect(result).to eq(:plain_scope)
      expect(described_class).to have_received(:plain_search).with(relation, 'john')
    end
  end

  describe '.plain_search' do
    it 'returns original relation when keyword is blank' do
      relation = double('relation')

      expect(described_class.plain_search(relation, '')).to eq(relation)
    end
  end

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

    it 'uses order groups and returns false when previous grouped submitter not completed' do
      s1 = double('s1', uuid: 'u1', completed_at?: false)
      s2 = double('s2', uuid: 'u2', completed_at?: false)
      submitter_items = [
        { 'uuid' => 'u1', 'order' => 1 },
        { 'uuid' => 'u2', 'order' => 2 }
      ]
      template = double('template', submitters: submitter_items)
      submission = double('submission', template_submitters: nil, template: template, submitters: [s1, s2])
      submitter = double('submitter', uuid: 'u2', submission: submission)

      expect(described_class.current_submitter_order?(submitter)).to be(false)
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

    it 'returns original blob filename when format is blank' do
      filename = double('filename', to_s: 'original.pdf')
      blob = double('blob', filename: filename)

      expect(described_class.build_document_filename(double('submitter'), blob, nil)).to eq('original.pdf')
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

  describe '.fulltext_search_field' do
    it 'returns none for blank keyword and unknown field name' do
      relation = double('relation')
      allow(relation).to receive(:none).and_return(:none_scope)

      expect(described_class.fulltext_search_field(double('user'), relation, '', 'email')).to eq(:none_scope)
      expect(described_class.fulltext_search_field(double('user'), relation, 'abc', 'unknown')).to eq(:none_scope)
    end

    it 'builds weighted query for special keywords split into multiple terms' do
      user = double('user', account_id: 7)
      submitters_relation = double('submitters_relation')
      search_relation = double('search_relation')
      allow(SearchEntries).to receive(:build_weights_tsquery).and_return(['tsvector @@ ...', { weight: 'A' }])
      allow(SearchEntry).to receive(:where).with(record_type: 'Submitter').and_return(search_relation)
      allow(search_relation).to receive(:where).with(account_id: 7).and_return(search_relation)
      allow(search_relation).to receive(:where).with('tsvector @@ ...', { weight: 'A' }).and_return(search_relation)
      allow(search_relation).to receive(:limit).with(500).and_return(search_relation)
      allow(search_relation).to receive(:pluck).with(:record_id).and_return((1..120).to_a)
      allow(submitters_relation).to receive(:where).with(id: (1..100).to_a).and_return(:filtered_scope)

      result = described_class.fulltext_search_field(user, submitters_relation, 'aa++bb', 'email')

      expect(result).to eq(:filtered_scope)
      expect(SearchEntries).to have_received(:build_weights_tsquery)
    end
  end

  describe '.verify_link_otp!' do
    it 'returns false for blank otp' do
      submitter = double('submitter')

      expect(described_class.verify_link_otp!('', submitter)).to be(false)
    end

    it 'raises InvalidOtp when verification fails' do
      template = double('template', slug: 'tpl-1')
      submission = double('submission', template: template)
      submitter = double('submitter', email: 'u@example.com', submission: submission)
      allow(RateLimit).to receive(:call)
      allow(EmailVerificationCodes).to receive(:verify).and_return(false)
      allow(I18n).to receive(:t).with(:invalid_code).and_return('invalid')

      expect do
        described_class.verify_link_otp!('123456', submitter)
      end.to raise_error(Submitters::InvalidOtp, 'invalid')
    end

    it 'returns true when otp is valid' do
      template = double('template', slug: 'tpl-1')
      submission = double('submission', template: template)
      submitter = double('submitter', email: 'u@example.com', submission: submission)
      allow(RateLimit).to receive(:call)
      allow(EmailVerificationCodes).to receive(:verify).and_return(true)

      expect(described_class.verify_link_otp!('123456', submitter)).to be(true)
    end
  end

  describe '.send_shared_link_email_verification_code' do
    it 'raises UnableToSendCode when rate limit is reached' do
      template = double('template', id: 12)
      submission = double('submission', template: template)
      submitter = double('submitter', email: 'to@example.com', submission: submission)
      request = double('request', remote_ip: '127.0.0.1')
      allow(RateLimit).to receive(:call).and_raise(RateLimit::LimitApproached)
      allow(I18n).to receive(:t).with('too_many_attempts').and_return('too many attempts')

      expect do
        described_class.send_shared_link_email_verification_code(submitter, request: request)
      end.to raise_error(Submitters::UnableToSendCode, 'too many attempts')
    end
  end

  describe '.select_attachments_for_download' do
    it 'returns combined document when account prefers combined results' do
      submission = double('submission', account_id: 1, submitters: [double('s', completed_at?: true)],
                                        template_fields: [], combined_document_attachment: :combined)
      submitter = double('submitter', submission: submission)
      allow(AccountConfig).to receive(:exists?).and_return(true)

      expect(described_class.select_attachments_for_download(submitter)).to eq([:combined])
    end

    it 'generates combined attachment when missing and account prefers combined results' do
      submission = double('submission', account_id: 1, submitters: [double('s', completed_at?: true)],
                                        template_fields: [], combined_document_attachment: nil)
      submitter = double('submitter', submission: submission)
      allow(AccountConfig).to receive(:exists?).and_return(true)
      allow(Submissions::EnsureCombinedGenerated).to receive(:call).with(submitter).and_return(:generated)

      expect(described_class.select_attachments_for_download(submitter)).to eq([:generated])
    end

    it 'does not return combined doc when a verification field exists' do
      schema_documents = double('schema_docs')
      allow(schema_documents).to receive(:preload).with(:blob).and_return([])
      submission = double('submission', account_id: 1, submitters: [double('s', completed_at?: true)],
                                        template_fields: [{ 'type' => 'verification' }],
                                        schema_documents: schema_documents)
      docs_preloaded = double('docs_preloaded')
      allow(docs_preloaded).to receive(:preload).with(:blob).and_return([])
      submitter = double('submitter', submission: submission, documents: docs_preloaded)
      allow(AccountConfig).to receive(:exists?).and_return(true)

      expect(described_class.select_attachments_for_download(submitter)).to eq([])
    end

    it 'rejects image attachments when multiple original images exist' do
      original_doc1 = double('orig1', uuid: 'd1', image?: true)
      original_doc2 = double('orig2', uuid: 'd2', image?: true)
      attachment = double('att', uuid: 'a1', metadata: { 'original_uuid' => 'd1' })
      schema_documents = double('schema_docs')
      allow(schema_documents).to receive(:preload).with(:blob).and_return([original_doc1, original_doc2])
      submission = double('submission', account_id: 1, submitters: [double('s', completed_at?: true)],
                                        template_fields: [{ 'type' => 'verification' }],
                                        schema_documents: schema_documents)
      docs_preloaded = double('docs_preloaded')
      allow(docs_preloaded).to receive(:preload).with(:blob).and_return([attachment])
      submitter = double('submitter', submission: submission, documents: docs_preloaded)
      allow(AccountConfig).to receive(:exists?).and_return(true)

      result = described_class.select_attachments_for_download(submitter)

      expect(result).to eq([])
    end
  end

  describe '.fulltext_search' do
    it 'returns original scope when keyword is blank' do
      scope = double('scope')

      expect(described_class.fulltext_search(double('user'), scope, '')).to eq(scope)
    end
  end

  describe '.plain_search with keyword' do
    it 'applies arel matchers when keyword is present' do
      relation = Submitter.all

      sql = described_class.plain_search(relation, 'foo').to_sql

      expect(sql).to include('%foo%')
      expect(sql).to match(/LOWER.*submitters.*email/i)
    end
  end

  describe '.fulltext_search_field numeric branches' do
    it 'handles short numeric keywords (ngram branch)' do
      user = double('user', account_id: 7)
      submitters_relation = double('submitters_relation')
      search_relation = double('search_relation')
      allow(SearchEntry).to receive(:where).with(record_type: 'Submitter').and_return(search_relation)
      allow(search_relation).to receive(:where).with(account_id: 7).and_return(search_relation)
      allow(search_relation).to receive(:where).and_return(search_relation)
      allow(search_relation).to receive(:limit).with(500).and_return(search_relation)
      allow(search_relation).to receive(:pluck).with(:record_id).and_return([1, 2, 3])
      allow(submitters_relation).to receive(:where).with(id: [1, 2, 3]).and_return(:scope)

      expect(described_class.fulltext_search_field(user, submitters_relation, '12', 'phone')).to eq(:scope)
    end

    it 'handles long numeric keywords (prefix branch)' do
      user = double('user', account_id: 7)
      submitters_relation = double('submitters_relation')
      search_relation = double('search_relation')
      allow(SearchEntry).to receive(:where).with(record_type: 'Submitter').and_return(search_relation)
      allow(search_relation).to receive(:where).with(account_id: 7).and_return(search_relation)
      allow(search_relation).to receive(:where).and_return(search_relation)
      allow(search_relation).to receive(:limit).with(500).and_return(search_relation)
      allow(search_relation).to receive(:pluck).with(:record_id).and_return([1])
      allow(submitters_relation).to receive(:where).with(id: [1]).and_return(:scope)

      expect(described_class.fulltext_search_field(user, submitters_relation, '01234567', 'phone')).to eq(:scope)
    end

    it 'uses build_weights_wildcard_tsquery for simple alphabetic keyword' do
      user = double('user', account_id: 7)
      submitters_relation = double('submitters_relation')
      search_relation = double('search_relation')
      allow(SearchEntries).to receive(:build_weights_wildcard_tsquery).and_return(['simple_q', 'A'])
      allow(SearchEntry).to receive(:where).with(record_type: 'Submitter').and_return(search_relation)
      allow(search_relation).to receive(:where).with(account_id: 7).and_return(search_relation)
      allow(search_relation).to receive(:where).and_return(search_relation)
      allow(search_relation).to receive(:limit).with(500).and_return(search_relation)
      allow(search_relation).to receive(:pluck).with(:record_id).and_return([42])
      allow(submitters_relation).to receive(:where).with(id: [42]).and_return(:scope)

      expect(described_class.fulltext_search_field(user, submitters_relation, 'alice', 'name')).to eq(:scope)
      expect(SearchEntries).to have_received(:build_weights_wildcard_tsquery).with('alice', 'C')
    end
  end

  describe '.current_submitter_order? without explicit order' do
    it 'returns true when all previous submitters in submitter_items list are completed' do
      s1 = double('s1', uuid: 'u1', completed_at?: true)
      submission = double('submission',
                          template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
                          submitters: [s1])
      submitter = double('submitter', uuid: 'u2', submission: submission)

      expect(described_class.current_submitter_order?(submitter)).to be(true)
    end

    it 'falls back to template.submitters when template_submitters is missing' do
      template = double('template', submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }])
      s1 = double('s1', uuid: 'u1', completed_at?: false)
      submission = double('submission', template_submitters: nil, template: template,
                                        submitters: [s1])
      submitter = double('submitter', uuid: 'u2', submission: submission)

      expect(described_class.current_submitter_order?(submitter)).to be(false)
    end
  end

  describe '.normalize_preferences without message' do
    it 'returns empty hash when nothing is set' do
      expect(described_class.normalize_preferences(double('account'), double('user'), {})).to eq({})
    end

    it 'parses bcc_completed and completed_redirect_url when provided' do
      params = { 'bcc_completed' => 'cc@example.com', 'completed_redirect_url' => 'https://done.example' }

      result = described_class.normalize_preferences(double('account'), double('user'), params)

      expect(result).to include('bcc_completed' => 'cc@example.com',
                                'completed_redirect_url' => 'https://done.example')
    end

    it 'creates email message from subject/body params when message is absent' do
      account = double('account')
      user = double('user')
      email_message = double('email_message', uuid: 'msg-99')
      allow(EmailMessages).to receive(:find_or_create_for_account_user)
        .with(account, user, 'Hi', 'Body').and_return(email_message)

      result = described_class.normalize_preferences(account, user, { 'subject' => 'Hi', 'body' => 'Body' })

      expect(result).to include('email_message_uuid' => 'msg-99')
    end
  end

  describe '.create_attachment! success' do
    it 'creates a blob and attachment for a safe file' do
      file = double('file', original_filename: 'doc.pdf', content_type: 'application/pdf',
                            open: double('io'))
      submitter = double('submitter')
      blob = double('blob')
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
      allow(ActiveStorage::Attachment).to receive(:create!).and_return(:attachment)

      result = described_class.create_attachment!(submitter, { file: file, name: 'attached_file' })

      expect(result).to eq(:attachment)
      expect(ActiveStorage::Attachment).to have_received(:create!).with(blob: blob, name: 'attached_file',
                                                                        record: submitter)
    end
  end

  describe '.build_document_filename with completed status' do
    it 'uses "completed" status when no signature fields exist' do
      filename = double('filename', to_s: 'contract.pdf', base: 'contract', extension: 'pdf')
      blob = double('blob', filename: filename)
      submission = double('submission',
                          submitters: [double('s', completed_at?: true)],
                          template_fields: [{ 'type' => 'text' }])
      account = double('account', timezone: 'UTC')
      submitter = double('submitter', submission: submission, completed_at: Time.current, account: account)

      allow(ReplaceEmailVariables).to receive(:call).and_return('{document.name} - {submission.status}')
      allow(I18n).to receive(:l).and_return('2026-05-11')
      allow(I18n).to receive(:t).with(:completed).and_return('Completed')

      result = described_class.build_document_filename(submitter, blob, 'fmt')

      expect(result).to include('Completed')
    end

    it 'omits status when not all submitters are completed' do
      filename = double('filename', to_s: 'contract.pdf', base: 'contract', extension: 'pdf')
      blob = double('blob', filename: filename)
      submission = double('submission',
                          submitters: [double('s', completed_at?: false)],
                          template_fields: [])
      account = double('account', timezone: 'UTC')
      submitter = double('submitter', submission: submission, completed_at: Time.current, account: account)

      allow(ReplaceEmailVariables).to receive(:call).and_return('{document.name} - {submission.status}')
      allow(I18n).to receive(:l).and_return('2026-05-11')

      result = described_class.build_document_filename(submitter, blob, 'fmt')

      expect(result).to eq('contract.pdf')
    end
  end
end
