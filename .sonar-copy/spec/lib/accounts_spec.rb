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
  end

  describe '.load_timeserver_url' do
    let(:account) { double('account') }

    it 'returns global timeserver url in multitenant mode' do
      allow(Docuseal).to receive(:multitenant?).and_return(true)
      stub_const('Docuseal::TIMESERVER_URL', 'https://tsa.example.test')

      expect(described_class.load_timeserver_url(account)).to eq('https://tsa.example.test')
    end
  end
end
