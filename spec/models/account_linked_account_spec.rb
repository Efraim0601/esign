# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountLinkedAccount do
  describe '#testing?' do
    it 'returns true when account_type is testing' do
      model = described_class.new(account_type: 'testing')

      expect(model.testing?).to be(true)
    end

    it 'returns false for non testing account_type' do
      model = described_class.new(account_type: 'production')

      expect(model.testing?).to be(false)
    end
  end
end
