# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReindexSearchEntryJob do
  describe '#perform' do
    it 'finds or initializes search entry and reindexes its record' do
      record = double('record')
      entry = double('entry', record: record)
      allow(SearchEntry).to receive(:find_or_initialize_by).and_return(entry)
      allow(SearchEntries).to receive(:reindex_record)

      described_class.new.perform('record_type' => 'Submission', 'record_id' => 4, 'extra' => 'ignored')

      expect(SearchEntry).to have_received(:find_or_initialize_by).with('record_type' => 'Submission', 'record_id' => 4)
      expect(SearchEntries).to have_received(:reindex_record).with(record)
    end
  end
end
