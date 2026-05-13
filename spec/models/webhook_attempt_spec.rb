# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookAttempt do
  describe '#success?' do
    it 'returns true for 2xx and 3xx responses' do
      expect(described_class.new(response_status_code: 201).success?).to be(true)
      expect(described_class.new(response_status_code: 302).success?).to be(true)
    end

    it 'returns false for 4xx/5xx responses' do
      expect(described_class.new(response_status_code: 404).success?).to be(false)
      expect(described_class.new(response_status_code: 500).success?).to be(false)
    end
  end
end
