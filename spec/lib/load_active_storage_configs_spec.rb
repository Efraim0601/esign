# frozen_string_literal: true

RSpec.describe LoadActiveStorageConfigs do
  describe '.reload' do
    it 'loads encrypted storage config and enables cloudflare compatibility flags' do
      env = double('env', test?: false, development?: false, local?: false)
      encrypted = double('encrypted',
                         value: {
                           'service' => 's3',
                           'configs' => { 'endpoint' => 'https://x.r2.cloudflarestorage.com' }
                         })
      parsed = { 's3' => { region: 'eu' } }
      registry = double('registry', fetch: :service)

      allow(Rails).to receive(:env).and_return(env)
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('LoadActiveStorageConfigs::IS_ENV_CONFIGURED', false)
      allow(EncryptedConfig).to receive(:find_by).and_return(encrypted)
      allow(ActiveSupport::ConfigurationFile).to receive(:parse).and_return(parsed)
      allow(ActiveStorage::Service::Registry).to receive(:new).and_return(registry)
      allow(ActiveStorage::Blob).to receive(:services=)
      allow(ActiveStorage::Blob).to receive(:services).and_return(registry)
      allow(ActiveStorage::Blob).to receive(:service=)

      described_class.reload

      expect(parsed['s3'][:force_path_style]).to be(true)
      expect(parsed['s3'][:request_checksum_calculation]).to eq('when_required')
      expect(ActiveStorage::Blob).to have_received(:services=).with(registry)
      expect(ActiveStorage::Blob).to have_received(:service=).with(:service)
      expect(described_class.loaded?).to be(true)
    end

    it 'parses google credentials json when service is google' do
      env = double('env', test?: false, development?: false, local?: false)
      encrypted = double('encrypted',
                         value: {
                           'service' => 'google',
                           'configs' => { 'credentials' => '{"type":"service_account"}' }
                         })
      parsed = { 'google' => {} }
      registry = double('registry', fetch: :service)

      allow(Rails).to receive(:env).and_return(env)
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      stub_const('LoadActiveStorageConfigs::IS_ENV_CONFIGURED', false)
      allow(EncryptedConfig).to receive(:find_by).and_return(encrypted)
      allow(ActiveSupport::ConfigurationFile).to receive(:parse).and_return(parsed)
      allow(ActiveStorage::Service::Registry).to receive(:new).and_return(registry)
      allow(ActiveStorage::Blob).to receive(:services=)
      allow(ActiveStorage::Blob).to receive(:services).and_return(registry)
      allow(ActiveStorage::Blob).to receive(:service=)

      described_class.reload

      expect(parsed['google'][:credentials]).to eq({ 'type' => 'service_account' })
    end
  end
end
