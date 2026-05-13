# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReindexAllSearchEntriesJob do
  describe '#perform' do
    it 'delegates full reindexing to SearchEntries' do
      allow(SearchEntries).to receive(:reindex_all)

      described_class.new.perform

      expect(SearchEntries).to have_received(:reindex_all)
    end
  end
end
