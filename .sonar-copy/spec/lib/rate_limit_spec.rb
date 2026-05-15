# frozen_string_literal: true

RSpec.describe RateLimit do
  before { described_class::STORE.clear }

  describe '.call' do
    it 'returns true when not enabled' do
      expect(described_class.call('any-key', limit: 1, ttl: 1.minute, enabled: false)).to be true
    end

    it 'allows calls below the limit' do
      key = "rate-limit-#{SecureRandom.hex(4)}"
      3.times { expect(described_class.call(key, limit: 5, ttl: 1.minute, enabled: true)).to be true }
    end

    it 'raises LimitApproached past the limit' do
      key = "rate-limit-#{SecureRandom.hex(4)}"
      2.times { described_class.call(key, limit: 2, ttl: 1.minute, enabled: true) }
      expect do
        described_class.call(key, limit: 2, ttl: 1.minute, enabled: true)
      end.to raise_error(described_class::LimitApproached)
    end

    it 'defaults enabled? to Docuseal.multitenant?' do
      allow(Docuseal).to receive(:multitenant?).and_return(false)
      key = "rate-limit-#{SecureRandom.hex(4)}"
      10.times { expect(described_class.call(key, limit: 1, ttl: 1.minute)).to be true }
    end
  end
end
