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
  end
end
