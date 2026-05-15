# frozen_string_literal: true

RSpec.describe JsonWebToken do
  let(:payload) { { 'user_id' => 42, 'role' => 'admin' } }

  describe '.encode' do
    it 'returns a JWT string' do
      token = described_class.encode(payload)
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end
  end

  describe '.decode' do
    it 'returns the original payload' do
      token = described_class.encode(payload)
      expect(described_class.decode(token)).to eq(payload)
    end

    it 'raises for tampered tokens' do
      token = described_class.encode(payload)
      tampered = "#{token}garbage"
      expect { described_class.decode(tampered) }.to raise_error(JWT::DecodeError)
    end
  end
end
