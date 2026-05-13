# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounts do
  describe '.generate_unique_test_email' do
    it 'returns base +test email when available' do
      allow(User).to receive(:exists?).with(email: 'john+test@example.com').and_return(false)

      expect(described_class.generate_unique_test_email('john@example.com')).to eq('john+test@example.com')
    end

    it 'increments suffix when previous test emails exist' do
      allow(User).to receive(:exists?).with(email: 'john+test@example.com').and_return(true)
      allow(User).to receive(:exists?).with(email: 'john+test1@example.com').and_return(true)
      allow(User).to receive(:exists?).with(email: 'john+test2@example.com').and_return(false)

      expect(described_class.generate_unique_test_email('john@example.com')).to eq('john+test2@example.com')
    end

    it 'falls back to timestamp when all reserved suffixes exist' do
      allow(User).to receive(:exists?).and_return(true)
      allow(Time).to receive_message_chain(:current, :to_i).and_return(1_700_000_000)

      expect(described_class.generate_unique_test_email('john@example.com')).to eq('john+test1700000000@example.com')
    end
  end

  describe '.can_send_emails?' do
    it 'returns true in multitenant mode' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)

      expect(described_class.can_send_emails?(double('account'))).to be(true)
    end

    it 'returns true when smtp env is configured' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).with('SMTP_ADDRESS').and_return('smtp.example.test')

      expect(described_class.can_send_emails?(double('account'))).to be(true)
    end

    it 'falls back to encrypted config existence when smtp env is missing' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).with('SMTP_ADDRESS').and_return(nil)
      allow(EncryptedConfig).to receive(:exists?).with(key: EncryptedConfig::EMAIL_SMTP_KEY).and_return(false)

      expect(described_class.can_send_emails?(double('account'))).to be(false)
    end
  end

  describe '.normalize_timezone' do
    it 'returns canonical timezone name when mapping exists' do
      expect(described_class.normalize_timezone('UTC')).to eq('UTC')
    end

    it 'falls back to UTC for invalid zones' do
      expect(described_class.normalize_timezone('INVALID/TZ')).to eq('UTC')
    end
  end

  describe '.load_signing_pkcs' do
    let(:account) { double('account') }

    it 'returns default pkcs when multitenant config is blank' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: nil))
      allow(Docuseal).to receive(:default_pkcs).and_return(:default_pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(:default_pkcs)
    end

    it 'delegates to GenerateCertificate when no custom default cert exists' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      cert_data = { 'cert' => 'C', 'sub_ca' => 'S', 'root_ca' => 'R', 'custom' => [] }
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: cert_data))
      allow(GenerateCertificate).to receive(:load_pkcs).with(cert_data).and_return(:pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(:pkcs)
    end

    it 'returns default pkcs for AATL custom default cert' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      cert_data = { 'custom' => [{ 'status' => 'default', 'name' => Docuseal::AATL_CERT_NAME }] }
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: cert_data))
      allow(Docuseal).to receive(:default_pkcs).and_return(:aatl_pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(:aatl_pkcs)
    end

    it 'loads custom default cert from pkcs data' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      encoded = Base64.urlsafe_encode64('pkcs-data')
      cert_data = { 'custom' => [{ 'status' => 'default', 'name' => 'Custom', 'data' => encoded, 'password' => 'pwd' }] }
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: cert_data))
      pkcs = double('pkcs')
      allow(OpenSSL::PKCS12).to receive(:new).with('pkcs-data', 'pwd').and_return(pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(pkcs)
    end
  end

  describe '.load_timeserver_url' do
    let(:account) { double('account') }

    it 'returns global timeserver url in multitenant mode' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      stub_const('Docuseal::TIMESERVER_URL', 'https://tsa.example.test')

      expect(described_class.load_timeserver_url(account)).to eq('https://tsa.example.test')
    end

    it 'returns account-specific timeserver url in single tenant mode' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY)
                                             .and_return(double('cfg', value: 'https://tsa.account.test'))

      expect(described_class.load_timeserver_url(account)).to eq('https://tsa.account.test')
    end
  end

  describe '.load_trusted_certs' do
    let(:account) { double('account') }

    it 'combines default cert, custom certs and trusted certs' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('Docuseal::CERTS', {})
      allow(EncryptedConfig).to receive(:find_by).with(key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: {
                                                                'cert' => 'cert-data',
                                                                'custom' => [{ 'data' => Base64.urlsafe_encode64('custom-data'),
                                                                               'password' => 'x' }]
                                                              }))
      default_pkcs = double('default_pkcs', certificate: :default_cert, ca_certs: [:default_ca])
      custom_pkcs = double('custom_pkcs', certificate: :custom_cert, ca_certs: [:custom_ca])
      allow(GenerateCertificate).to receive(:load_pkcs).and_return(default_pkcs)
      allow(OpenSSL::PKCS12).to receive(:new).and_return(custom_pkcs)
      allow(Docuseal).to receive(:trusted_certs).and_return([:global_cert])

      trusted = described_class.load_trusted_certs(account)

      expect(trusted).to include(:default_cert, :default_ca, :custom_cert, :custom_ca, :global_cert)
    end

    it 'skips unusable default cert and still returns custom certificates' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('Docuseal::CERTS', {})
      allow(EncryptedConfig).to receive(:find_by).with(key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: {
                                                                'cert' => 'bad-cert',
                                                                'custom' => [{ 'data' => Base64.urlsafe_encode64('custom-data'),
                                                                               'password' => '' }]
                                                              }))
      allow(GenerateCertificate).to receive(:load_pkcs).and_raise(StandardError, 'broken')
      allow(Rails.logger).to receive(:warn)
      custom_pkcs = double('custom_pkcs', certificate: :custom_cert, ca_certs: nil)
      allow(OpenSSL::PKCS12).to receive(:new).and_return(custom_pkcs)
      allow(Docuseal).to receive(:trusted_certs).and_return([])

      trusted = described_class.load_trusted_certs(account)

      expect(trusted).to eq([:custom_cert])
      expect(Rails.logger).to have_received(:warn).with(/\[load_trusted_certs\]/)
    end
  end

  describe '.link_expires_at' do
    it 'returns nil when download links expiration is disabled' do
      account = double('account')
      config = double('config', value: false)
      allow(AccountConfig).to receive(:find_or_initialize_by).with(account: account, key: AccountConfig::DOWNLOAD_LINKS_EXPIRE_KEY)
                                                    .and_return(config)

      expect(described_class.link_expires_at(account)).to be_nil
    end

    it 'returns future timestamp when links expiration is enabled' do
      account = double('account')
      config = double('config', value: true)
      allow(AccountConfig).to receive(:find_or_initialize_by).and_return(config)

      expect(described_class.link_expires_at(account)).to be_within(1.second).of(Accounts::LINK_EXPIRES_AT.from_now)
    end
  end

  describe '.can_send_invitation_emails?' do
    it 'always returns true' do
      expect(described_class.can_send_invitation_emails?(double('account'))).to be(true)
    end
  end

  describe '.load_recipient_form_fields' do
    it 'returns an empty array' do
      expect(described_class.load_recipient_form_fields(double('account'))).to eq([])
    end
  end

  describe '.load_signing_pkcs (single-tenant)' do
    let(:account) { double('account') }

    it 'returns default pkcs when CERTS are present' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('Docuseal::CERTS', { 'cert' => 'data' })
      allow(Docuseal).to receive(:default_pkcs).and_return(:default_pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(:default_pkcs)
    end

    it 'loads account-specific config first when CERTS are blank' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('Docuseal::CERTS', {})
      cert_data = { 'cert' => 'C', 'custom' => [] }
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: cert_data))
      allow(GenerateCertificate).to receive(:load_pkcs).with(cert_data).and_return(:pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(:pkcs)
    end

    it 'falls back to global encrypted config when no account config exists' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('Docuseal::CERTS', {})
      cert_data = { 'cert' => 'C', 'custom' => [] }
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(nil)
      allow(EncryptedConfig).to receive(:find_by).with(key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(double('enc', value: cert_data))
      allow(GenerateCertificate).to receive(:load_pkcs).with(cert_data).and_return(:pkcs)

      expect(described_class.load_signing_pkcs(account)).to eq(:pkcs)
    end
  end

  describe '.load_timeserver_url single-tenant fallback' do
    let(:account) { double('account') }

    it 'falls back to first account encrypted config when account has no config' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY)
                                             .and_return(nil)
      first_account = double('first_account')
      configs = double('configs')
      allow(Account).to receive(:order).with(:id).and_return(double(first: first_account))
      allow(first_account).to receive(:encrypted_configs).and_return(configs)
      allow(configs).to receive(:find_by).with(key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY)
                                     .and_return(double('cfg', value: 'https://global.tsa.test'))

      expect(described_class.load_timeserver_url(account)).to eq('https://global.tsa.test')
    end

    it 'returns nil when no timeserver is configured anywhere' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY)
                                             .and_return(nil)
      first_account = double('first_account')
      configs = double('configs')
      allow(Account).to receive(:order).with(:id).and_return(double(first: first_account))
      allow(first_account).to receive(:encrypted_configs).and_return(configs)
      allow(configs).to receive(:find_by).with(key: EncryptedConfig::TIMESTAMP_SERVER_URL_KEY).and_return(nil)

      expect(described_class.load_timeserver_url(account)).to be_nil
    end
  end

  describe '.load_trusted_certs in multitenant mode' do
    let(:account) { double('account') }

    it 'merges Docuseal::CERTS with account config values' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      stub_const('Docuseal::CERTS', { 'cert' => 'global', 'custom' => [] })
      allow(EncryptedConfig).to receive(:find_by).with(account: account, key: EncryptedConfig::ESIGN_CERTS_KEY)
                                             .and_return(nil)
      allow(GenerateCertificate).to receive(:load_pkcs).and_return(double('pkcs', certificate: :gc, ca_certs: nil))
      allow(Docuseal).to receive(:trusted_certs).and_return([])

      trusted = described_class.load_trusted_certs(account)

      expect(trusted).to include(:gc)
    end
  end

  describe '.normalize_timezone with mapped name' do
    it 'returns ActiveSupport friendly name for friendly mapping' do
      expect(described_class.normalize_timezone('Eastern Time (US & Canada)'))
        .to eq('Eastern Time (US & Canada)')
    end
  end

  describe '.users_count' do
    it 'counts active users for the account and excludes archived users' do
      account = create(:account)
      create(:user, account: account, role: :admin)
      archived_user = create(:user, account: account, role: :member)
      archived_user.update!(archived_at: Time.current)

      expect(described_class.users_count(account)).to eq(1)
    end

    it 'includes linked-account members but excludes archived linked accounts' do
      account = create(:account)
      create(:user, account: account, role: :admin)
      linked = create(:account)
      AccountLinkedAccount.create!(account: account, linked_account: linked, account_type: :linked)
      create(:user, account: linked, role: :editor)
      archived_linked = create(:account, archived_at: Time.current)
      AccountLinkedAccount.create!(account: account, linked_account: archived_linked, account_type: :linked)
      create(:user, account: archived_linked, role: :editor)

      expect(described_class.users_count(account)).to eq(2)
    end
  end

  describe '.create_duplicate' do
    it 'creates a brand-new account, user and clones templates' do
      account = create(:account)
      original_user = create(:user, account: account, email: 'admin@example.com')
      original_user.update_column(:uuid, SecureRandom.uuid) if original_user.has_attribute?(:uuid)
      author_for_folder = create(:user, account: account)
      template = create(:template, account: account, author: author_for_folder,
                                   submitter_count: 0, attachment_count: 0)
      allow(Templates::CloneAttachments).to receive(:call)

      # The production method does not reset uuid on the duplicated account; assign one
      # to the original so the .dup gets a unique value via the model's default proc.
      allow_any_instance_of(Account).to receive(:dup).and_wrap_original do |orig|
        clone = orig.call
        clone.uuid = SecureRandom.uuid
        clone
      end

      new_account = nil
      expect do
        new_account = described_class.create_duplicate(account)
      end.to change(Account, :count).by(1)

      expect(new_account.templates.first).not_to eq(template)
      expect(Templates::CloneAttachments).to have_received(:call)
    end
  end

  describe '.find_or_create_testing_user' do
    it 'returns the existing admin in the testing account when present' do
      account = create(:account)
      testing_account = create(:account, name: 'Testing - X')
      AccountLinkedAccount.create!(account: account, linked_account: testing_account, account_type: :testing)
      testing_admin = create(:user, account: testing_account, email: 'admin+test@example.com', role: :admin)

      expect(described_class.find_or_create_testing_user(account)).to eq(testing_admin)
    end

    it 'creates a new testing account and admin user when none exists' do
      account = create(:account, name: 'Org')
      create(:user, account: account, email: 'real@example.com', role: :admin)

      expect do
        described_class.find_or_create_testing_user(account)
      end.to change(Account, :count).by(1).and change(User, :count).by(1)

      testing_account = account.testing_accounts.first
      expect(testing_account.name).to eq('Testing - Org')
      expect(testing_account.users.first.role).to eq('admin')
      expect(testing_account.users.first.email).to start_with('real+test')
    end
  end

  describe '.create_default_template' do
    it 'duplicates Template id 1 into the target account' do
      original_account = create(:account)
      original_user = create(:user, account: original_account)
      template1 = create(:template, account: original_account, author: original_user,
                                    submitter_count: 0, attachment_count: 0)
      allow(Template).to receive(:find).with(1).and_return(template1)
      allow(SearchEntries).to receive(:enqueue_reindex)
      allow(Templates::CloneAttachments).to receive(:call)

      new_account = create(:account)
      create(:user, account: new_account)

      expect do
        described_class.create_default_template(new_account)
      end.to change { new_account.templates.count }.by(1)

      new_template = new_account.templates.first
      expect(new_template.folder).to eq(new_account.default_template_folder)
      expect(SearchEntries).to have_received(:enqueue_reindex).with(new_template)
    end
  end
end
