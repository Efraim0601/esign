# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchEntries do
  describe '.reindex_all' do
    it 'reindexes submitters, submissions and templates' do
      submitter = double('submitter')
      submission = double('submission')
      template = double('template')

      allow(Submitter).to receive(:find_each).and_yield(submitter)
      allow(Submission).to receive(:find_each).and_yield(submission)
      allow(Template).to receive(:find_each).and_yield(template)
      allow(described_class).to receive(:index_submitter)
      allow(described_class).to receive(:index_submission)
      allow(described_class).to receive(:index_template)

      described_class.reindex_all

      expect(described_class).to have_received(:index_submitter).with(submitter)
      expect(described_class).to have_received(:index_submission).with(submission)
      expect(described_class).to have_received(:index_template).with(template)
    end
  end

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

    it 'builds ngram query for short keyword with or vector' do
      sql, binds = described_class.build_tsquery('ab', with_or_vector: true)

      expect(sql).to include('ngram @@')
      expect(sql).to include('plainto_tsquery')
      expect(binds[:keyword]).to eq('ab')
    end

    it 'builds numeric query for one-digit number' do
      sql, number, normalized_number, keyword = described_class.build_tsquery('0')

      expect(sql).to include('ngram @@')
      expect(number).to eq('0')
      expect(normalized_number).to eq('0')
      expect(keyword).to eq('0')
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

    it 'returns short-keyword ngram sql when keyword has two chars' do
      sql, binds = described_class.build_weights_wildcard_tsquery('ok', 'C')

      expect(sql).to include('ngram @@')
      expect(sql).to include(':weight')
      expect(binds[:keyword]).to eq('ok')
      expect(binds[:weight]).to eq('C')
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

    it 'does not duplicate existing hyphen token' do
      entry = double('entry', tsvector: "'AB-12':1")
      allow(entry).to receive(:tsvector=)

      described_class.add_hyphens(entry, 'AB-12')

      expect(entry).not_to have_received(:tsvector=)
    end
  end

  describe '.build_ngram' do
    it 'adds first two and first one character variants' do
      result = described_class.build_ngram("'abcd':1,2 'xy':3")

      expect(result).to include("'ab':", "'a':", "'xy':", "'x':")
    end
  end

  describe '.enqueue_reindex' do
    it 'does nothing when search_entries table does not exist' do
      allow(SearchEntry).to receive(:table_exists?).and_return(false)
      allow(ReindexSearchEntryJob).to receive(:perform_bulk)

      described_class.enqueue_reindex(double('record'))

      expect(ReindexSearchEntryJob).not_to have_received(:perform_bulk)
    end

    it 'enqueues records when table exists' do
      record1 = double('record1', id: 1, class: Submitter)
      record2 = double('record2', id: 2, class: Submission)
      allow(SearchEntry).to receive(:table_exists?).and_return(true)
      allow(ReindexSearchEntryJob).to receive(:perform_bulk)

      described_class.enqueue_reindex([record1, record2])

      expect(ReindexSearchEntryJob).to have_received(:perform_bulk).with(
        [
          [{ 'record_type' => 'Submitter', 'record_id' => 1 }],
          [{ 'record_type' => 'Submission', 'record_id' => 2 }]
        ]
      )
    end
  end

  describe '.reindex_record' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }

    it 'indexes submitter records' do
      submission = create(:submission, template: create(:template, account:, author:,
                                                                   submitter_count: 0, attachment_count: 0),
                                       created_by_user: author)
      submitter = create(:submitter, submission:, account:)
      allow(described_class).to receive(:index_submitter)

      described_class.reindex_record(submitter)

      expect(described_class).to have_received(:index_submitter).with(submitter)
    end

    it 'indexes template records' do
      template = create(:template, account:, author:, submitter_count: 0, attachment_count: 0)
      allow(described_class).to receive(:index_template)

      described_class.reindex_record(template)

      expect(described_class).to have_received(:index_template).with(template)
    end

    it 'indexes submission and nested submitters' do
      template = create(:template, account:, author:, submitter_count: 0, attachment_count: 0)
      submission = create(:submission, template:, created_by_user: author)
      child_submitter = create(:submitter, submission:, account:)
      allow(described_class).to receive(:index_submission)
      allow(described_class).to receive(:index_submitter)

      described_class.reindex_record(submission)

      expect(described_class).to have_received(:index_submission).with(submission)
      expect(described_class).to have_received(:index_submitter).with(child_submitter)
    end

    it 'raises for unsupported record type' do
      expect { described_class.reindex_record(double('other')) }.to raise_error(ArgumentError, 'Invalid Record')
    end
  end

  describe '.index_submitter' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let(:template) { create(:template, account:, author:, submitter_count: 0, attachment_count: 0) }
    let(:submission) { create(:submission, template:, created_by_user: author) }

    it 'creates a search entry with tsvector and ngram for a populated submitter' do
      submitter = create(:submitter, submission:, account:, email: 'jane@example.com',
                                     name: 'Jane Doe', phone: '+33712345678',
                                     values: { 'f1' => 'Important Notes' })

      entry = described_class.index_submitter(submitter)

      expect(entry).to be_persisted
      expect(entry.tsvector).not_to be_blank
      expect(entry.account_id).to eq(account.id)
    end

    it 'returns nil for a submitter without identifying values' do
      submitter = create(:submitter, submission:, account:, email: nil, name: nil, phone: nil)

      expect(described_class.index_submitter(submitter)).to be_nil
    end
  end

  describe '.index_template' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }

    it 'creates a search entry for a named template' do
      template = create(:template, account:, author:, name: 'Lease Contract 2026',
                                   submitter_count: 0, attachment_count: 0)

      entry = described_class.index_template(template)

      expect(entry).to be_persisted
      expect(entry.tsvector).not_to be_blank
      expect(entry.account_id).to eq(account.id)
    end
  end

  describe '.index_submission' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let(:template) { create(:template, account:, author:, submitter_count: 0, attachment_count: 0) }

    it 'returns nil when submission has no name' do
      submission = create(:submission, template:, created_by_user: author, name: nil)

      expect(described_class.index_submission(submission)).to be_nil
    end

    it 'creates a search entry when submission has a name' do
      submission = create(:submission, template:, created_by_user: author, name: 'Quarterly Report Q1')

      entry = described_class.index_submission(submission)

      expect(entry).to be_persisted
      expect(entry.tsvector).not_to be_blank
    end
  end

  describe '.build_tsquery edge cases' do
    it 'handles short keyword without with_or_vector flag' do
      sql, binds = described_class.build_tsquery('ab')

      expect(sql.to_s).to include('ngram')
      expect(binds[:keyword]).to eq('ab')
    end

    it 'handles quoted keyword' do
      sql, arg = described_class.build_tsquery('"important"')

      expect(sql).to include('plainto_tsquery')
      expect(arg).to eq('"important"')
    end

    it 'handles double-dot keyword as plainto query' do
      sql, arg = described_class.build_tsquery('foo..bar')

      expect(sql).to include('plainto_tsquery')
      expect(arg).to eq('foo..bar')
    end

    it 'strips null bytes from input' do
      _, binds = described_class.build_tsquery("ap\0proval")

      expect(binds[:keyword]).to eq('approval')
    end
  end

  describe '.build_weights_tsquery short last term' do
    it 'builds ngram-based query when last term is short' do
      sql, binds = described_class.build_weights_tsquery(%w[contract si ab], 'B')

      expect(sql).to include('ngram')
      expect(binds[:weight]).to eq('B')
      expect(binds[:term2]).to eq('ab')
    end
  end

  describe '.build_ngram empty' do
    it 'returns blank string when ngram is blank' do
      expect(described_class.build_ngram('')).to eq('')
    end
  end
end
