# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#initials' do
    it 'returns initials uppercased and ignores blanks' do
      user = build_stubbed(:user, first_name: 'Ada', last_name: 'Lovelace')
      expect(user.initials).to eq('AL')

      user = build_stubbed(:user, first_name: nil, last_name: 'Lovelace')
      expect(user.initials).to eq('L')
    end
  end

  describe '#full_name' do
    it 'joins first and last name' do
      user = build_stubbed(:user, first_name: 'Ada', last_name: 'Lovelace')
      expect(user.full_name).to eq('Ada Lovelace')
    end
  end

  describe '#friendly_name' do
    it 'uses quoted full name when present' do
      user = build_stubbed(:user, first_name: 'A"da', last_name: 'Love"lace', email: 'ada@example.com')
      expect(user.friendly_name).to eq(%("Ada Lovelace" <ada@example.com>))
    end

    it 'falls back to email when name is blank' do
      user = build_stubbed(:user, first_name: nil, last_name: nil, email: 'ada@example.com')
      expect(user.friendly_name).to eq('ada@example.com')
    end
  end

  describe '#sidekiq?' do
    it 'returns true in development' do
      user = build_stubbed(:user, role: 'viewer')
      allow(Rails.env).to receive(:development?).and_return(true)
      expect(user.sidekiq?).to be(true)
    end

    it 'returns true only for admin in non-development' do
      allow(Rails.env).to receive(:development?).and_return(false)

      expect(build_stubbed(:user, role: 'admin').sidekiq?).to be(true)
      expect(build_stubbed(:user, role: 'member').sidekiq?).to be(false)
    end
  end
end

