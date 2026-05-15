# frozen_string_literal: true

RSpec.describe Templates::Order do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }

  describe '.call' do
    let!(:template_a) { create(:template, account:, author:, name: 'Alpha') }
    let!(:template_b) { create(:template, account:, author:, name: 'Bravo') }

    it 'orders by name ascending when order is "name"' do
      result = described_class.call(account.templates, author, 'name')
      expect(result.pluck(:name)).to eq(%w[Alpha Bravo])
    end

    it 'orders by id descending for unknown order values' do
      result = described_class.call(account.templates, author, 'whatever')
      expect(result.pluck(:id)).to eq([template_b.id, template_a.id])
    end

    it 'orders by id descending when order is nil' do
      result = described_class.call(account.templates, author, nil)
      expect(result.pluck(:id)).to eq([template_b.id, template_a.id])
    end

    it 'returns templates joined with their last submission for "used_at"' do
      create(:submission, template: template_a, created_by_user: author, created_at: 2.days.ago)
      create(:submission, template: template_b, created_by_user: author, created_at: 1.minute.ago)

      result = described_class.call(account.templates, author, 'used_at')

      expect(result.to_a).to include(template_a, template_b)
    end
  end
end
