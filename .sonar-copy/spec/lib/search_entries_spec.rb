# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchEntries do
  describe '.build_tsquery' do
    it 'builds numeric query for digit-only keyword' do
      sql, *args = described_class.build_tsquery('0123')

      expect(sql).to include('tsvector')
      expect(args.flatten.join(' ')).to include('0123')
    end

    it 'builds plainto query for special characters keyword' do
      sql, arg = described_class.build_tsquery('a@@b!!')

      expect(sql).to include('plainto_tsquery')
      expect(arg).to eq(TextUtils.transliterate('a@@b!!'.downcase))
    end

    it 'builds wildcard query for normal text keyword' do
      sql, binds = described_class.build_tsquery('approval')

      expect(sql).to include("':*'")
      expect(binds[:keyword]).to eq('approval')
    end
  end

  describe '.build_weights_tsquery' do
    it 'returns sql and binds for weighted terms query' do
      sql, binds = described_class.build_weights_tsquery(%w[contract si], 'A')

      expect(sql).to include('tsvector')
      expect(binds[:weight]).to eq('A')
      expect(binds[:term0]).to eq('contract')
      expect(binds[:term1]).to eq('si')
    end
  end

  describe '.build_weights_wildcard_tsquery' do
    it 'returns wildcard sql for keyword longer than two chars' do
      sql, binds = described_class.build_weights_wildcard_tsquery('approval', 'B')

      expect(sql).to include("':*'")
      expect(binds[:keyword]).to eq('approval')
      expect(binds[:weight]).to eq('B')
    end
  end

  describe '.build_submitter_values_string' do
    it 'keeps short string values and filters uuids/long values' do
      submitter = double('submitter', values: {
                           'a' => 'Valid Value',
                           'b' => '550e8400-e29b-41d4-a716-446655440000',
                           'c' => 'x' * (SearchEntries::MAX_VALUE_LENGTH + 1),
                           'd' => %w[Two Three]
                         })

      result = described_class.build_submitter_values_string(submitter)

      expect(result).to include('valid value', 'two', 'three')
      expect(result).not_to include('550e8400')
    end
  end

  describe '.add_hyphens' do
    it 'adds hyphenated tokens to tsvector when missing' do
      entry = double('entry', tsvector: "'foo':1")
      allow(entry).to receive(:tsvector=)

      described_class.add_hyphens(entry, 'AB-12 x 9-test')

      expect(entry).to have_received(:tsvector=).at_least(:once)
    end
  end

  describe '.build_ngram' do
    it 'adds first two and first one character variants' do
      result = described_class.build_ngram("'abcd':1,2 'xy':3")

      expect(result).to include("'ab':", "'a':", "'xy':", "'x':")
    end
  end
end
