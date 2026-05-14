# frozen_string_literal: true

RSpec.describe Docuseal::DefaultAdminSeeder do
  describe '.call' do
    it 'returns early for multitenant setups' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)

      expect(described_class.call).to be_nil
    end

    it 'returns early when seeding is disabled' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEFAULT_ADMIN_SEED').and_return('false')

      expect(described_class.call).to be_nil
    end
  end

  describe '.ensure_default_esign_certs!' do
    it 'creates default cert config when missing' do
      account = double('account', id: 1, encrypted_configs: double('assoc'))

      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('encrypted_configs').and_return(true)
      allow(EncryptedConfig).to receive(:exists?).with(key: EncryptedConfig::ESIGN_CERTS_KEY).and_return(false)
      allow(GenerateCertificate).to receive(:call).and_return({ cert: double(to_pem: 'PEM') })
      allow(account.encrypted_configs).to receive(:create!)
      allow(Rails.logger).to receive(:info)

      described_class.ensure_default_esign_certs!(account)

      expect(account.encrypted_configs).to have_received(:create!).with(
        key: EncryptedConfig::ESIGN_CERTS_KEY,
        value: { cert: 'PEM' }
      )
    end

    it 'logs an error when certificate creation fails' do
      account = double('account', id: 1, encrypted_configs: double('assoc'))

      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('encrypted_configs').and_return(true)
      allow(EncryptedConfig).to receive(:exists?).and_return(false)
      allow(GenerateCertificate).to receive(:call).and_raise(StandardError, 'boom')
      allow(Rails.logger).to receive(:error)

      described_class.ensure_default_esign_certs!(account)

      expect(Rails.logger).to have_received(:error).with(/unable to seed eSign certificate/)
    end

    it 'returns early when users table does not exist' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEFAULT_ADMIN_SEED').and_return(nil)
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('users').and_return(false)

      expect(described_class.call).to be_nil
    end

    it 'returns early when accounts table does not exist' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEFAULT_ADMIN_SEED').and_return(nil)
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('users').and_return(true)
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('accounts').and_return(false)

      expect(described_class.call).to be_nil
    end

    it 'skips certificate provisioning when EncryptedConfig already exists' do
      account = double('account', id: 1, encrypted_configs: double('assoc'))
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('encrypted_configs').and_return(true)
      allow(EncryptedConfig).to receive(:exists?).and_return(true)
      allow(GenerateCertificate).to receive(:call)

      described_class.ensure_default_esign_certs!(account)

      expect(GenerateCertificate).not_to have_received(:call)
    end

    it 'returns early when encrypted_configs table does not exist' do
      account = double('account', id: 1)
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('encrypted_configs').and_return(false)

      expect(described_class.ensure_default_esign_certs!(account)).to be_nil
    end
  end

  describe '.call full path with seed' do
    before do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DEFAULT_ADMIN_SEED').and_return(nil)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).and_return(true)
      allow(described_class).to receive(:ensure_default_esign_certs!)
    end

    it 'seeds a default admin user when none exists yet' do
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_EMAIL', 'admin@afb.com').and_return('seed@example.test')
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_PASSWORD', 'admin').and_return('password123')

      expect do
        described_class.call
      end.to change(User, :count).by(1)

      expect(User.find_by(email: 'seed@example.test')).not_to be_nil
    end

    it 'short-circuits gracefully when user already exists' do
      account = create(:account)
      create(:user, account:, email: 'seed@example.test', role: :admin)
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_EMAIL', 'admin@afb.com').and_return('seed@example.test')
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_PASSWORD', 'admin').and_return('password123')

      expect do
        described_class.call
      end.not_to change(User, :count)
    end

    it 'uses bcrypt directly when password is shorter than 6 chars' do
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_EMAIL', 'admin@afb.com').and_return('short@example.test')
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_PASSWORD', 'admin').and_return('abc')

      expect do
        described_class.call
      end.to change(User, :count).by(1)

      expect(User.find_by(email: 'short@example.test').encrypted_password).not_to be_blank
    end

    it 'rescues ActiveRecord::RecordNotUnique gracefully' do
      allow(User).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_EMAIL', 'admin@afb.com').and_return('unique@example.test')
      allow(ENV).to receive(:fetch).with('DEFAULT_ADMIN_PASSWORD', 'admin').and_return('password123')

      expect(described_class.call).to be_nil
    end
  end
end
