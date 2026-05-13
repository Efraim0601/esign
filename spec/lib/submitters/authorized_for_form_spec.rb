# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::AuthorizedForForm do
  describe '.totp_user_for' do
    let(:account) { create(:account) }
    let(:template) { create(:template, account:, author: create(:user, account:), submitter_count: 0, attachment_count: 0) }
    let(:submission) { create(:submission, template:) }

    context 'when no user matches the submitter email' do
      let(:submitter) { create(:submitter, submission:, email: 'stranger@example.com') }

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end

    context 'when a user matches but has not enabled TOTP' do
      let(:submitter) { create(:submitter, submission:, email: 'alice@example.com') }

      before do
        create(:user, account:, email: 'alice@example.com', otp_required_for_login: false)
      end

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end

    context 'when a user matches in another account' do
      let(:other_account) { create(:account) }
      let(:submitter) { create(:submitter, submission:, email: 'alice@example.com') }

      before do
        create(:user, account: other_account, email: 'alice@example.com',
                      otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end

    context 'when a matching user has TOTP enabled in the same account' do
      let(:submitter) { create(:submitter, submission:, email: 'Alice@Example.com ') }
      let!(:user) do
        create(:user, account:, email: 'alice@example.com',
                      otp_required_for_login: true, otp_secret: User.generate_otp_secret)
      end

      it 'returns the user (case- and whitespace-insensitive)' do
        expect(described_class.totp_user_for(submitter)).to eq(user)
      end
    end

    context 'when submitter has no email' do
      let(:submitter) { create(:submitter, submission:, email: nil) }

      it 'returns nil' do
        expect(described_class.totp_user_for(submitter)).to be_nil
      end
    end
  end

  describe '.call and 2FA checks' do
    let(:request) do
      double('request', cookie_jar: double('cookies', encrypted: {}), params: {}, headers: {})
    end

    it 'returns false when submitter is nil' do
      expect(described_class.call(nil, nil, request)).to be(false)
    end

    it 'returns true when neither template, submitter, nor account requires email 2FA' do
      template = double('template', preferences: { 'require_email_2fa' => false })
      submission = double('submission', template: template, source: 'web')
      submitter = double('submitter', submission: submission, preferences: {},
                                       account_id: 1, slug: 'abc',
                                       email: nil)
      allow(described_class).to receive(:account_requires_email_2fa?).with(submitter).and_return(false)

      expect(described_class.call(submitter, nil, request)).to be(true)
    end

    it 'passes when encrypted cookie matches submitter slug' do
      template = double('template', preferences: { 'require_email_2fa' => true })
      submission = double('submission', template: template, source: 'web')
      submitter = double('submitter', submission: submission, preferences: {}, slug: 's1',
                                       account_id: 1, email: nil)
      req = double('request',
                   cookie_jar: double('cookies', encrypted: { email_2fa_slug: 's1' }),
                   params: {}, headers: {})

      expect(described_class.pass_email_2fa?(submitter, req)).to be(true)
    end

    it 'passes when valid two_factor_token is provided' do
      template = double('template', preferences: { 'require_email_2fa' => true })
      submission = double('submission', template: template, source: 'web')
      submitter = double('submitter', submission: submission, preferences: {}, slug: 's2',
                                       account_id: 1, email: nil)
      verifier = double('verifier')
      allow(Submitter).to receive(:signed_id_verifier).and_return(verifier)
      allow(verifier).to receive(:verified).with('tok', purpose: :email_two_factor).and_return('s2')

      req = double('request',
                   cookie_jar: double('cookies', encrypted: {}),
                   params: { two_factor_token: 'tok' }, headers: {})

      expect(described_class.pass_email_2fa?(submitter, req)).to be(true)
    end

    it 'falls back to x-two-factor-token header when params are missing' do
      template = double('template', preferences: { 'require_email_2fa' => true })
      submission = double('submission', template: template, source: 'web')
      submitter = double('submitter', submission: submission, preferences: {}, slug: 's3',
                                       account_id: 1, email: nil)
      verifier = double('verifier')
      allow(Submitter).to receive(:signed_id_verifier).and_return(verifier)
      allow(verifier).to receive(:verified).with('hdr-tok', purpose: :email_two_factor).and_return('s3')

      req = double('request',
                   cookie_jar: double('cookies', encrypted: {}),
                   params: {}, headers: { 'x-two-factor-token' => 'hdr-tok' })

      expect(described_class.pass_email_2fa?(submitter, req)).to be(true)
    end

    it 'returns false when token does not verify' do
      template = double('template', preferences: { 'require_email_2fa' => true })
      submission = double('submission', template: template, source: 'web')
      submitter = double('submitter', submission: submission, preferences: {}, slug: 's4',
                                       account_id: 1, email: nil)
      verifier = double('verifier')
      allow(Submitter).to receive(:signed_id_verifier).and_return(verifier)
      allow(verifier).to receive(:verified).with('bad', purpose: :email_two_factor).and_return('other')

      req = double('request',
                   cookie_jar: double('cookies', encrypted: {}),
                   params: { two_factor_token: 'bad' }, headers: {})

      expect(described_class.pass_email_2fa?(submitter, req)).to be(false)
    end
  end

  describe '.pass_link_2fa?' do
    let(:request) do
      double('request', cookie_jar: double('cookies', encrypted: {}), params: {}, headers: {})
    end

    it 'returns false when submitter is nil' do
      expect(described_class.pass_link_2fa?(nil, nil, request)).to be(false)
    end

    it 'returns true when submission is not from a shared link' do
      submission = double('submission', source: 'email', template: nil)
      submitter = double('submitter', submission: submission)

      expect(described_class.pass_link_2fa?(submitter, nil, request)).to be(true)
    end

    it 'returns true when template does not require shared link 2FA' do
      template = double('template', preferences: { 'shared_link_2fa' => false })
      submission = double('submission', source: 'link', template: template)
      submitter = double('submitter', submission: submission)

      expect(described_class.pass_link_2fa?(submitter, nil, request)).to be(true)
    end

    it 'returns true when current user matches submitter in same account' do
      template = double('template', preferences: { 'shared_link_2fa' => true })
      submission = double('submission', source: 'link', template: template)
      submitter = double('submitter', submission: submission, email: 'u@x.com',
                                       account_id: 1, slug: 's1')
      current_user = double('current_user', email: 'u@x.com', account_id: 1)

      expect(described_class.pass_link_2fa?(submitter, current_user, request)).to be(true)
    end

    it 'returns true with cookie email_2fa_slug match' do
      template = double('template', preferences: { 'shared_link_2fa' => true })
      submission = double('submission', source: 'link', template: template)
      submitter = double('submitter', submission: submission, email: 'u@x.com', slug: 's1')
      req = double('request',
                   cookie_jar: double('cookies', encrypted: { email_2fa_slug: 's1' }),
                   params: {}, headers: {})

      expect(described_class.pass_link_2fa?(submitter, nil, req)).to be(true)
    end

    it 'validates two_factor_token against email+template_slug key' do
      template = double('template', preferences: { 'shared_link_2fa' => true }, slug: 'tpl-123')
      submission = double('submission', source: 'link', template: template)
      submitter = double('submitter', submission: submission, email: 'A@X.com  ', slug: 's1', account_id: 1)
      verifier = double('verifier')
      key = 'a@x.com:tpl-123'
      allow(Submitter).to receive(:signed_id_verifier).and_return(verifier)
      allow(verifier).to receive(:verified).with('tok', purpose: :email_two_factor).and_return(key)

      req = double('request',
                   cookie_jar: double('cookies', encrypted: {}),
                   params: { two_factor_token: 'tok' }, headers: {})

      expect(described_class.pass_link_2fa?(submitter, nil, req)).to be(true)
    end

    it 'returns false when 2FA token does not match key' do
      template = double('template', preferences: { 'shared_link_2fa' => true }, slug: 'tpl-123')
      submission = double('submission', source: 'link', template: template)
      submitter = double('submitter', submission: submission, email: 'a@x.com', slug: 's1', account_id: 1)
      verifier = double('verifier')
      allow(Submitter).to receive(:signed_id_verifier).and_return(verifier)
      allow(verifier).to receive(:verified).and_return('other-key')

      req = double('request',
                   cookie_jar: double('cookies', encrypted: {}),
                   params: { two_factor_token: 'tok' }, headers: {})

      expect(described_class.pass_link_2fa?(submitter, nil, req)).to be(false)
    end
  end

  describe '.account_requires_email_2fa?' do
    it 'queries AccountConfig with correct key' do
      submitter = double('submitter', account_id: 7)
      allow(AccountConfig).to receive(:exists?).and_return(true)

      expect(described_class.account_requires_email_2fa?(submitter)).to be(true)
      expect(AccountConfig).to have_received(:exists?).with(
        account_id: 7,
        key: AccountConfig::REQUIRE_SUBMITTER_EMAIL_2FA_KEY,
        value: true
      )
    end
  end
end
