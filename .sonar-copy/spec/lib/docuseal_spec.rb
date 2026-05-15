# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Docuseal do
  describe '.multitenant?' do
    it 'returns true when MULTITENANT env is true' do
      allow(ENV).to receive(:[]).with('MULTITENANT').and_return('true')

      expect(described_class.multitenant?).to be(true)
    end
  end

  describe '.demo?' do
    it 'returns false by default' do
      allow(ENV).to receive(:[]).with('DEMO').and_return(nil)

      expect(described_class.demo?).to be(false)
    end
  end

  describe '.fulltext_search?' do
    it 'returns false when search_entries table does not exist' do
      described_class.instance_variable_set(:@fulltext_search, nil)
      allow(SearchEntry).to receive(:table_exists?).and_return(false)

      expect(described_class.fulltext_search?).to be(false)
    end
  end

  describe '.refresh_default_url_options!' do
    it 'clears memoized default url options' do
      described_class.instance_variable_set(:@default_url_options, { host: 'x' })

      described_class.refresh_default_url_options!

      expect(described_class.instance_variable_get(:@default_url_options)).to be_nil
    end
  end
end
