# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitter do
  describe '#status' do
    it 'returns declined when declined_at is present' do
      expect(described_class.new(declined_at: Time.current).status).to eq('declined')
    end

    it 'returns completed when completed_at is present' do
      expect(described_class.new(completed_at: Time.current).status).to eq('completed')
    end
  end

  describe '#friendly_name' do
    it 'formats display name with email' do
      submitter = described_class.new(name: 'Alice "A"', email: 'alice@example.test')

      expect(submitter.friendly_name).to eq('"Alice A" <alice@example.test>')
    end
  end

  describe '#application_key' do
    it 'returns external_id' do
      expect(described_class.new(external_id: 'ext-1').application_key).to eq('ext-1')
    end
  end
end
