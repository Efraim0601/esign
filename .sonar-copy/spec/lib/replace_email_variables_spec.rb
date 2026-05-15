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
  end
end
