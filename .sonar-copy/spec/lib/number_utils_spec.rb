# frozen_string_literal: true

RSpec.describe NumberUtils do
  describe '.format_number' do
    it 'formats with comma delimiter (en locale)' do
      expect(described_class.format_number(1234.5, 'comma')).to eq('1,234.5')
    end

    it 'formats with dot delimiter (de locale)' do
      expect(described_class.format_number(1234.5, 'dot')).to eq('1.234,5')
    end

    it 'formats with space delimiter (fr locale)' do
      result = described_class.format_number(1234.5, 'space')
      expect(result).to match(/1.234,5/)
    end

    it 'formats USD currency' do
      expect(described_class.format_number(1234.5, 'usd')).to eq('$1,234.50')
    end

    it 'formats EUR currency' do
      result = described_class.format_number(1234.5, 'eur')
      expect(result).to include('€')
      expect(result).to include('1')
    end

    it 'formats GBP currency' do
      expect(described_class.format_number(1234.5, 'gbp')).to eq('£1,234.50')
    end

    it 'returns the number unchanged when format is unknown' do
      expect(described_class.format_number(1234.5, 'unknown')).to eq(1234.5)
    end
  end
end
