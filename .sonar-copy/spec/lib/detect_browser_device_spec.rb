# frozen_string_literal: true

RSpec.describe DetectBrowserDevice do
  describe '.call' do
    it 'returns nil for blank user agent' do
      expect(described_class.call(nil)).to be_nil
      expect(described_class.call('')).to be_nil
    end

    it 'detects iPhone as mobile' do
      ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15'
      expect(described_class.call(ua)).to eq('mobile')
    end

    it 'detects Android phones as mobile' do
      ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Mobile Safari/537.36'
      expect(described_class.call(ua)).to eq('mobile')
    end

    it 'detects Windows Phone as mobile' do
      ua = 'Mozilla/5.0 (compatible; Windows Phone 10.0)'
      expect(described_class.call(ua)).to eq('mobile')
    end

    it 'detects iPad as tablet' do
      ua = 'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)'
      expect(described_class.call(ua)).to eq('tablet')
    end

    it 'detects Android tablets (no Mobile token) as tablet' do
      ua = 'Mozilla/5.0 (Linux; Android 14; Tab S9) AppleWebKit/537.36'
      expect(described_class.call(ua)).to eq('tablet')
    end

    it 'detects Kindle as tablet' do
      ua = 'Mozilla/5.0 (Linux; U; Android 4.0.3; en-us; KFTT Build/IML74K) Silk/3.4'
      expect(described_class.call(ua)).to eq('tablet')
    end

    it 'returns desktop for typical desktop user agents' do
      ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0'
      expect(described_class.call(ua)).to eq('desktop')
    end
  end
end
