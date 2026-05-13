# frozen_string_literal: true

RSpec.describe Submitters::FormConfigs do
  describe '.call' do
    it 'builds form config attributes from account configs' do
      configs = [
        double('cfg1', key: AccountConfig::FORM_WITH_CONFETTI_KEY, value: false),
        double('cfg2', key: AccountConfig::ALLOW_TYPED_SIGNATURE, value: true),
        double('cfg3', key: AccountConfig::WITH_SIGNATURE_ID, value: false),
        double('cfg4', key: 'custom_key', value: 'x')
      ]
      relation = double('relation')
      account_configs = double('account_configs')
      account = double('account', account_configs: account_configs)
      submission = double('submission', account: account)
      submitter = double('submitter', submission: submission)

      allow(account_configs).to receive(:where).and_return(relation)
      allow(relation).to receive(:find) { |&blk| configs.find(&blk) }

      attrs = described_class.call(submitter, ['custom_key'])

      expect(attrs[:with_confetti]).to be(false)
      expect(attrs[:with_typed_signature]).to be(true)
      expect(attrs[:with_signature_id]).to be(false)
      expect(attrs[:custom_key]).to eq('x')
    end
  end

  describe '.find_safe_value' do
    it 'returns nil when config does not exist' do
      expect(described_class.find_safe_value([], 'missing')).to be_nil
    end
  end
end
