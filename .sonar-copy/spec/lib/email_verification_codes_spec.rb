# frozen_string_literal: true

RSpec.describe EmailVerificationCodes do
  let(:value) { 'user@example.com' }

  describe '.generate' do
    it 'returns a 6-digit numeric code' do
      code = described_class.generate(value)
      expect(code).to match(/\A\d{6}\z/)
    end

    it 'returns the same code within the same TOTP window' do
      code1 = described_class.generate(value)
      code2 = described_class.generate(value)
      expect(code1).to eq(code2)
    end

    it 'returns different codes for different values' do
      code_a = described_class.generate('a@example.com')
      code_b = described_class.generate('b@example.com')
      expect(code_a).not_to eq(code_b)
    end
  end

  describe '.verify' do
    it 'verifies a freshly generated code' do
      code = described_class.generate(value)
      expect(described_class.verify(code, value)).to be_truthy
    end

    it 'returns falsy for an incorrect code' do
      expect(described_class.verify('000000', value)).to be_falsey
    end

    it 'rejects a code generated for a different value' do
      code = described_class.generate('other@example.com')
      expect(described_class.verify(code, value)).to be_falsey
    end
  end

  describe '.build_totp_secret' do
    it 'returns a Base32-encoded string' do
      secret = described_class.build_totp_secret(value)
      expect(secret).to match(/\A[A-Z2-7=]+\z/)
    end

    it 'is deterministic for the same input' do
      expect(described_class.build_totp_secret(value)).to eq(described_class.build_totp_secret(value))
    end
  end
end
