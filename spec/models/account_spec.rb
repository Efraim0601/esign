# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account do
  describe '#testing?' do
    it 'returns nil when no linked account record' do
      account = build_stubbed(:account)
      expect(account.testing?).to be_nil
    end
  end

  describe '#tz_info' do
    it 'returns a TZInfo::Timezone for the configured timezone' do
      account = build_stubbed(:account, timezone: 'UTC')
      expect(account.tz_info).to be_a(TZInfo::Timezone)
    end
  end
end

