# frozen_string_literal: true

RSpec.describe UserConfigs do
  let(:user) { create(:user) }

  describe '.load_signature' do
    it 'returns nil when user is blank' do
      expect(described_class.load_signature(nil)).to be_nil
    end

    it 'returns nil when no signature config exists' do
      expect(described_class.load_signature(user)).to be_nil
    end

    it 'returns nil when uuid points to no attachment' do
      create(:user_config, user:, key: UserConfig::SIGNATURE_KEY, value: SecureRandom.uuid)
      expect(described_class.load_signature(user)).to be_nil
    end
  end

  describe '.load_initials' do
    it 'returns nil when user is blank' do
      expect(described_class.load_initials(nil)).to be_nil
    end

    it 'returns nil when no initials config exists' do
      expect(described_class.load_initials(user)).to be_nil
    end

    it 'returns nil when uuid points to no attachment' do
      create(:user_config, user:, key: UserConfig::INITIALS_KEY, value: SecureRandom.uuid)
      expect(described_class.load_initials(user)).to be_nil
    end
  end
end
