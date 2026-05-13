# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateCertificate do
  describe '.call' do
    it 'returns all required cert and key parts' do
      result = described_class.call('FirstSign')

      expect(result.keys).to include(:cert, :key, :root_ca, :root_key, :sub_ca, :sub_key)
      expect(result[:cert]).to be_a(OpenSSL::X509::Certificate)
      expect(result[:key]).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe '.generate_root_ca' do
    it 'creates a self-signed CA certificate' do
      cert, key = described_class.generate_root_ca('FirstSign')

      expect(cert.subject.to_s).to include('Root CA')
      expect(cert.issuer.to_s).to eq(cert.subject.to_s)
      expect(key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe '.generate_sub_ca' do
    it 'creates a subordinate CA signed by root' do
      root_cert, root_key = described_class.generate_root_ca('FirstSign')
      cert, key = described_class.generate_sub_ca('FirstSign', root_cert, root_key)

      expect(cert.subject.to_s).to include('Sub-CA')
      expect(cert.issuer.to_s).to eq(root_cert.subject.to_s)
      expect(key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe '.generate_certificate' do
    it 'creates end-entity certificate signed by sub ca' do
      root_cert, root_key = described_class.generate_root_ca('FirstSign')
      sub_cert, sub_key = described_class.generate_sub_ca('FirstSign', root_cert, root_key)

      cert, key = described_class.generate_certificate('FirstSign', sub_cert, sub_key)

      expect(cert.subject.to_s).to include('/CN=FirstSign')
      expect(cert.issuer.to_s).to eq(sub_cert.subject.to_s)
      expect(key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe '.load_pkcs' do
    it 'returns pkcs12 struct when private key is absent' do
      generated = described_class.call('FirstSign')
      cert_data = {
        'cert' => generated[:cert].to_pem,
        'sub_ca' => generated[:sub_ca].to_pem,
        'root_ca' => generated[:root_ca].to_pem,
        'key' => nil
      }

      result = described_class.load_pkcs(cert_data)

      expect(result).to be_a(GenerateCertificate::Pkcs12Struct)
      expect(result.certificate).to be_a(OpenSSL::X509::Certificate)
      expect(result.ca_certs.size).to eq(2)
    end

    it 'returns OpenSSL::PKCS12 when key is provided' do
      generated = described_class.call('FirstSign')
      cert_data = {
        'cert' => generated[:cert].to_pem,
        'sub_ca' => generated[:sub_ca].to_pem,
        'root_ca' => generated[:root_ca].to_pem,
        'key' => generated[:key].to_pem
      }

      result = described_class.load_pkcs(cert_data)

      expect(result).to be_a(OpenSSL::PKCS12)
      expect(result.certificate).to be_a(OpenSSL::X509::Certificate)
    end
  end
end
