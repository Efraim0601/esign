# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReplaceEmailVariables do
  describe '.replace' do
    it 'replaces variable occurrences without html escaping by default' do
      result = described_class.replace('Hello {{name}}', /\{+name\}+/i) { 'Alice & Bob' }

      expect(result).to eq('Hello Alice & Bob')
    end

    it 'escapes replacement when html_escape is true' do
      result = described_class.replace('Hello {{name}}', /\{+name\}+/i, html_escape: true) { '<Admin>' }

      expect(result).to eq('Hello &lt;Admin&gt;')
    end
  end

  describe '.build_submission_submitters' do
    it 'joins unique submitter display names ordered by completed_at' do
      ordered = double('ordered')
      s1 = double('s1', name: 'Alice', email: nil, phone: nil)
      s2 = double('s2', name: nil, email: 'bob@example.test', phone: nil)
      submission = double('submission', submitters: ordered)
      allow(ordered).to receive(:order).with(:completed_at).and_return([s1, s2, s1])

      expect(described_class.build_submission_submitters(submission)).to eq('Alice, bob@example.test')
    end
  end

  describe '.build_url_options_for' do
    it 'returns custom domain url options in multitenant mode' do
      submitter = double('submitter', account_id: 12)
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      allow(AccountConfig).to receive(:find_by).with(account_id: 12, key: :custom_domain)
                                           .and_return(double(value: 'tenant.example.test'))

      expect(described_class.build_url_options_for(submitter)).to eq(
        host: 'tenant.example.test',
        protocol: 'https'
      )
    end

    it 'uses EMAIL_HOST for email links when present' do
      submitter = double('submitter', account_id: 12)
      stub_const('ReplaceEmailVariables::EMAIL_HOST', 'mail.example.test')
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FORCE_SSL').and_return('1')

      expect(described_class.build_url_options_for(submitter, is_email: true)).to eq(
        host: 'mail.example.test',
        protocol: 'https'
      )
    end

    it 'returns default url options when no custom domain and no email host' do
      submitter = double('submitter', account_id: 12)
      stub_const('ReplaceEmailVariables::EMAIL_HOST', nil)
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(Docuseal).to receive(:default_url_options).and_return({ host: 'app.example.test', protocol: 'https' })

      expect(described_class.build_url_options_for(submitter, is_email: false)).to eq(
        host: 'app.example.test', protocol: 'https'
      )
    end
  end

  describe '.build_submitter_link' do
    it 'uses email tracking param for click_email events' do
      submitter = double('submitter', slug: 'abc', account_id: 1)
      helpers = double('helpers')

      allow(described_class).to receive(:build_url_options_for).with(submitter, is_email: true)
                                                           .and_return(host: 'app.test', protocol: 'https')
      allow(SubmissionEvents).to receive(:build_tracking_param).with(submitter, 'click_email').and_return('tok')
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))
      allow(helpers).to receive(:submit_form_url).and_return('https://app.test/s/abc?t=tok')

      result = described_class.build_submitter_link(submitter, 'click_email')

      expect(result).to include('t=tok')
    end

    it 'uses sms tracking param for non email events' do
      submitter = double('submitter', slug: 'abc', account_id: 1)
      helpers = double('helpers')

      allow(described_class).to receive(:build_url_options_for).with(submitter, is_email: false)
                                                           .and_return(host: 'app.test', protocol: 'https')
      allow(SubmissionEvents).to receive(:build_tracking_param).with(submitter, 'click_sms').and_return('sms-tok')
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))
      allow(helpers).to receive(:submit_form_url).and_return('https://app.test/s/abc?c=sms-tok')

      result = described_class.build_submitter_link(submitter, 'click_sms')

      expect(result).to include('c=sms-tok')
    end
  end

  describe '.build_submitters_n_field' do
    it 'returns named field value for requested submitter index' do
      target_submitter = double('submitter', uuid: 'u2', values: { 'field-uuid' => 'VALUE' }, attachments: [])
      submission = double(
        'submission',
        template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
        submitters: [target_submitter],
        template_fields: [{ 'name' => 'Reference', 'uuid' => 'field-uuid', 'type' => 'text' }],
        template: double(submitters: [], fields: [])
      )

      value = described_class.build_submitters_n_field(submission, 1, :values, 'Reference')

      expect(value).to eq('VALUE')
    end

    it 'returns nil when indexed submitter is missing' do
      submission = double(
        'submission',
        template_submitters: [{ 'uuid' => 'u1' }],
        submitters: [],
        template_fields: [],
        template: double(submitters: [], fields: [])
      )

      expect(described_class.build_submitters_n_field(submission, 0, :email)).to be_nil
    end

    it 'returns attachment url for image-like field values' do
      blob = double('blob')
      attachment = double('attachment', uuid: 'att-1', blob: blob)
      target_submitter = double('submitter', uuid: 'u2', values: { 'field-uuid' => 'att-1' }, attachments: [attachment])
      submission = double(
        'submission',
        account_id: 77,
        template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
        submitters: [target_submitter],
        template_fields: [{ 'name' => 'Image Field', 'uuid' => 'field-uuid', 'type' => 'image' }],
        template: double(submitters: [], fields: [])
      )
      allow(Accounts).to receive(:link_expires_at).with(instance_of(Account)).and_return(Time.current + 1.hour)
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob, expires_at: kind_of(Time)).and_return('https://file.test/1')

      value = described_class.build_submitters_n_field(submission, 1, :values, 'Image Field')

      expect(value).to eq('https://file.test/1')
    end
  end

  describe '.build_documents_links_text' do
    it 'builds preview url with optional signature param' do
      helpers = double('helpers')
      submission = double('submission', slug: 'sub-1')
      submitter = double('submitter', submission: submission, account_id: 1)
      allow(described_class).to receive(:build_url_options_for).with(submitter).and_return(host: 'app.test', protocol: 'https')
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))
      allow(helpers).to receive(:submissions_preview_url).and_return('https://app.test/e/sub-1?sig=abc')

      url = described_class.build_documents_links_text(submitter, 'abc')

      expect(url).to include('sig=abc')
    end
  end

  describe '.call substitution coverage' do
    let(:template) { double('template', id: 7, name: 'Tpl', submitters: [], fields: []) }
    let(:created_by) { double('created_by_user', full_name: 'Jane Smith', first_name: 'Jane', email: 'jane+team@example.com') }
    let(:account) { double('account', name: 'ACME', timezone: 'UTC', locale: 'en-US') }
    let(:helpers) { double('helpers') }

    def build_submitter(values: {}, attachments: [], submitters: nil, submission_name: 'Doc')
      submission = double(
        'submission',
        name: submission_name,
        slug: 'sub-slug',
        id: 99,
        account: account,
        account_id: 1,
        template: template,
        template_submitters: submitters || [{ 'uuid' => 'u1' }],
        template_fields: template.fields,
        expire_at: nil,
        created_by_user: created_by,
        submitters: submitters_collection(submitters)
      )
      double(
        'submitter',
        uuid: 'u1',
        id: 5,
        slug: 'sub-1',
        email: 'a@example.com',
        first_name: 'Alice',
        name: 'Alice Bob',
        phone: '+33700000000',
        template: template,
        submission: submission,
        account_id: 1,
        attachments: attachments,
        values: values
      )
    end

    def submitters_collection(items)
      list = (items || [{ 'uuid' => 'u1' }]).map do |item|
        double('s', uuid: item['uuid'], name: 'Alice', email: 'a@example.com', phone: nil,
                    first_name: 'Alice', values: {}, attachments: [])
      end
      class << list
        def order(*); self end
      end
      list
    end

    before do
      allow(Rails.application).to receive(:routes).and_return(double('routes', url_helpers: helpers))
      allow(helpers).to receive(:submit_form_url).and_return('https://app.test/s/sub-1?t=tok')
      allow(helpers).to receive(:submissions_preview_url).and_return('https://app.test/e/sub-slug')
      allow(helpers).to receive(:submission_url).and_return('https://app.test/sub/99')
      allow(SubmissionEvents).to receive(:build_tracking_param).and_return('tok')
      allow(described_class).to receive(:build_url_options_for).and_return(host: 'app.test', protocol: 'https')
    end

    it 'substitutes core template, submitter, account and sender placeholders' do
      submitter = build_submitter
      text = 'Tpl={{template.name}} Sub={{submitter.name}} Email={{submitter.email}} ' \
             'Slug={{submitter.slug}} Id={{submitter.id}} SubId={{submission.id}} ' \
             'Account={{account.name}} Sender={{sender.name}} ' \
             'SenderEmail={{sender.email}} SenderFirst={{sender.first_name}} ' \
             'Link={{submitter.link}} SubmissionLink={{submission.link}} ' \
             'TemplateId={{template.id}} FirstName={{submitter.first_name}}'

      result = described_class.call(text, submitter: submitter)

      expect(result).to include('Tpl=Tpl')
      expect(result).to include('Sub=Alice Bob')
      expect(result).to include('Email=a@example.com')
      expect(result).to include('Slug=sub-1')
      expect(result).to include('Id=5')
      expect(result).to include('SubId=99')
      expect(result).to include('Account=ACME')
      expect(result).to include('Sender=Jane Smith')
      expect(result).to include('SenderEmail=jane@example.com')
      expect(result).to include('SenderFirst=Jane')
      expect(result).to include('TemplateId=7')
      expect(result).to include('FirstName=Alice')
    end

    it 'returns submission name and submitters list' do
      submitter = build_submitter
      text = 'Name={{submission.name}} List={{submitters}}'

      result = described_class.call(text, submitter: submitter)

      expect(result).to include('Name=Doc')
      expect(result).to include('Alice')
    end

    it 'returns documents links variant' do
      submitter = build_submitter
      text = 'Docs={{documents.link}} DocsAll={{documents.links}}'

      result = described_class.call(text, submitter: submitter)

      expect(result).to include('Docs=https://app.test/e/sub-slug')
      expect(result).to include('DocsAll=https://app.test/e/sub-slug')
    end

    it 'html-escapes when html_escape is enabled' do
      submitter = build_submitter
      allow(submitter).to receive(:name).and_return('<Alice>')

      result = described_class.call('Name={{submitter.name}}', submitter: submitter, html_escape: true)

      expect(result).to include('&lt;Alice&gt;')
    end

    it 'falls back to email and phone when submitter name is blank' do
      submitter = build_submitter
      allow(submitter).to receive(:name).and_return(nil)

      expect(described_class.call('X={{submitter.name}}', submitter: submitter)).to include('X=a@example.com')
    end

    it 'returns expire_at when configured' do
      submitter = build_submitter
      time = Time.utc(2026, 5, 13, 12, 0)
      allow(submitter.submission).to receive(:expire_at).and_return(time)
      allow(I18n).to receive(:l).and_return('2026-05-13 12:00 UTC')

      expect(described_class.call('When={{submission.expire_at}}', submitter: submitter))
        .to include('When=2026-05-13 12:00 UTC')
    end
  end
end
