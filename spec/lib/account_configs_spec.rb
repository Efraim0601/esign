# frozen_string_literal: true

RSpec.describe AccountConfigs do
  let(:account) { create(:account) }

  describe '.find_for_account' do
    context 'when the account already has a config for the key' do
      let!(:config) { create(:account_config, account:, key: 'a_key', value: 'value-1') }

      it 'returns the matching config' do
        expect(described_class.find_for_account(account, 'a_key')).to eq(config)
      end
    end

    context 'when no config exists' do
      it 'returns nil in multitenant mode', multitenant: true do
        expect(described_class.find_for_account(account, 'missing_key')).to be_nil
      end

      it 'falls back to the first account config in self-hosted mode' do
        primary_account = create(:account)
        secondary_account = create(:account)
        fallback = create(:account_config, account: primary_account, key: 'global_key', value: 'fallback')

        expect(described_class.find_for_account(secondary_account, 'global_key')).to eq(fallback)
      end
    end
  end

  describe '.find_or_initialize_for_key' do
    it 'returns an existing config when present' do
      existing = create(:account_config, account:, key: AccountConfig::ALLOW_TYPED_SIGNATURE, value: 'true')
      expect(described_class.find_or_initialize_for_key(account, AccountConfig::ALLOW_TYPED_SIGNATURE)).to eq(existing)
    end

    it 'builds an unsaved config seeded with default value when none exists', multitenant: true do
      result = described_class.find_or_initialize_for_key(account, AccountConfig::ALLOW_TYPED_SIGNATURE)
      expect(result).to be_a(AccountConfig)
      expect(result).to be_new_record
      expect(result.key).to eq(AccountConfig::ALLOW_TYPED_SIGNATURE)
    end
  end

  describe '.submitter_reminder_offsets' do
    it 'returns empty when no reminders configured', multitenant: true do
      expect(described_class.submitter_reminder_offsets(account)).to eq([])
    end

    it 'maps configured reminder durations to seconds' do
      create(:account_config,
             account:,
             key: AccountConfig::SUBMITTER_REMINDERS,
             value: { 'first_duration' => 'one_hour', 'second_duration' => 'two_days', 'third_duration' => nil })

      result = described_class.submitter_reminder_offsets(account)

      expect(result).to contain_exactly(
        ['first_duration', 1.hour],
        ['second_duration', 2.days]
      )
    end

    it 'skips entries with unknown durations' do
      create(:account_config,
             account:,
             key: AccountConfig::SUBMITTER_REMINDERS,
             value: { 'first_duration' => 'unknown_duration', 'second_duration' => 'one_hour' })

      result = described_class.submitter_reminder_offsets(account)

      expect(result).to contain_exactly(['second_duration', 1.hour])
    end
  end
end
