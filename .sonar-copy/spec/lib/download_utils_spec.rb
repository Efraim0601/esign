# frozen_string_literal: true

RSpec.describe DownloadUtils do
  describe '.validate_uri!' do
    it 'allows https URIs on default port' do
      expect { described_class.validate_uri!(URI('https://example.com/file.pdf')) }.not_to raise_error
    end

    it 'allows https URIs on port 443 explicitly' do
      expect { described_class.validate_uri!(URI('https://example.com:443/file.pdf')) }.not_to raise_error
    end

    it 'rejects http URIs' do
      expect { described_class.validate_uri!(URI('http://example.com/file.pdf')) }
        .to raise_error(described_class::UnableToDownload, /Only HTTPS is allowed/)
    end

    it 'rejects https URIs on non-443 ports' do
      expect { described_class.validate_uri!(URI('https://example.com:8443/file.pdf')) }
        .to raise_error(described_class::UnableToDownload, /Only HTTPS is allowed/)
    end

    it 'rejects localhost' do
      expect { described_class.validate_uri!(URI('https://localhost/file.pdf')) }
        .to raise_error(described_class::UnableToDownload, /Can't download from localhost/)
    end

    it 'rejects 127.0.0.1' do
      expect { described_class.validate_uri!(URI('https://127.0.0.1/file.pdf')) }
        .to raise_error(described_class::UnableToDownload, /Can't download from localhost/)
    end

    it 'rejects IPv6 loopback' do
      expect { described_class.validate_uri!(URI('https://[::1]/file.pdf')) }
        .to raise_error(described_class::UnableToDownload, /Can't download from localhost/)
    end
  end

  describe '.call' do
    it 'returns the response when the URL is reachable' do
      stub_request(:get, 'https://example.com/file.pdf').to_return(status: 200, body: 'pdf-bytes')

      response = described_class.call('https://example.com/file.pdf', validate: true)

      expect(response.status).to eq(200)
      expect(response.body).to eq('pdf-bytes')
    end

    it 'raises UnableToDownload when the response is 4xx/5xx' do
      stub_request(:get, 'https://example.com/missing.pdf').to_return(status: 404)

      expect { described_class.call('https://example.com/missing.pdf', validate: true) }
        .to raise_error(described_class::UnableToDownload, /Error loading/)
    end

    it 'rejects http URLs when validation is on' do
      expect { described_class.call('http://example.com/file.pdf', validate: true) }
        .to raise_error(described_class::UnableToDownload, /Only HTTPS is allowed/)
    end

    it 'rejects localhost URLs when validation is on' do
      expect { described_class.call('https://localhost/file.pdf', validate: true) }
        .to raise_error(described_class::UnableToDownload, /Can't download from localhost/)
    end
  end
end
