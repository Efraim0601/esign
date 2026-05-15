# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::Filter do
  describe '.normalize_filter_params' do
    it 'keeps allowed keys and parses date fields in account timezone' do
      account = double('account', timezone: 'Europe/Paris')
      current_user = double('user', account: account)

      filters = described_class.normalize_filter_params(
        { 'author' => 'a@example.test', 'created_at_from' => '2026-05-01', 'ignored' => 'x' },
        current_user
      )

      expect(filters[:author]).to eq('a@example.test')
      expect(filters[:created_at_from]).to be_a(Time)
      expect(filters).not_to have_key(:ignored)
    end
  end

  describe '.filter_by_author' do
    it 'filters by found author id' do
      users = double('users')
      account = double('account', users: users)
      current_user = double('user', account: account)
      submissions = double('submissions')
      found_user = double('found_user', id: 44)

      allow(users).to receive(:find_by).with(email: 'a@example.test').and_return(found_user)
      allow(submissions).to receive(:where).with(created_by_user_id: 44).and_return(:filtered)

      result = described_class.filter_by_author(submissions, { author: 'a@example.test' }, current_user)

      expect(result).to eq(:filtered)
    end
  end

  describe '.filter_by_status' do
    it 'returns pending scope for pending status' do
      submissions = double('submissions')
      allow(submissions).to receive(:pending).and_return(:pending_scope)

      expect(described_class.filter_by_status(submissions, { status: 'pending' })).to eq(:pending_scope)
    end

    it 'returns original scope for unknown status' do
      submissions = double('submissions')

      expect(described_class.filter_by_status(submissions, { status: 'unknown' })).to eq(submissions)
    end
  end
end
