# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhoneCodes do
  describe 'ALL' do
    it 'contains common international dialing codes' do
      expect(described_class::ALL).to include('+1', '+33', '+44', '+49', '+91', '+971')
    end
  end

  describe 'REGEXP' do
    it 'matches valid phone prefixes at string beginning' do
      expect('+33612345678').to match(described_class::REGEXP)
      expect('+14155550123').to match(described_class::REGEXP)
    end

    it 'does not match when no valid prefix is present' do
      expect('0033612345678').not_to match(described_class::REGEXP)
      expect('abcdef').not_to match(described_class::REGEXP)
    end
  end
end
