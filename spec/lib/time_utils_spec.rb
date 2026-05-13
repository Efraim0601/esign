# frozen_string_literal: true

RSpec.describe TimeUtils do
  describe '.timezone_abbr' do
    it 'returns UTC for nil timezone' do
      expect(described_class.timezone_abbr(nil)).to eq('UTC')
    end

    it 'maps Rails timezone names through ActiveSupport mapping' do
      expect(described_class.timezone_abbr('Pacific Time (US & Canada)', Time.utc(2024, 1, 15))).to eq('PST')
    end

    it 'accepts raw IANA timezone identifiers' do
      expect(described_class.timezone_abbr('Europe/Paris', Time.utc(2024, 7, 15))).to eq('CEST')
    end
  end

  describe '.parse_time_value' do
    it 'parses an integer epoch (seconds)' do
      expect(described_class.parse_time_value(1_700_000_000).to_i).to eq(1_700_000_000)
    end

    it 'truncates millisecond integers to seconds' do
      expect(described_class.parse_time_value(1_700_000_000_000).to_i).to eq(1_700_000_000)
    end

    it 'parses ISO 8601 strings' do
      result = described_class.parse_time_value('2024-01-15T12:00:00Z')
      expect(result).to be_a(ActiveSupport::TimeWithZone)
      expect(result.year).to eq(2024)
    end

    it 'returns nil for blank input' do
      expect(described_class.parse_time_value(nil)).to be_nil
      expect(described_class.parse_time_value('')).to be_nil
    end
  end

  describe '.parse_date_string' do
    it 'parses ISO format' do
      expect(described_class.parse_date_string('2024-01-15', 'YYYY-MM-DD')).to eq(Date.new(2024, 1, 15))
    end

    it 'parses US format' do
      expect(described_class.parse_date_string('01/15/2024', 'MM/DD/YYYY')).to eq(Date.new(2024, 1, 15))
    end

    it 'parses two-digit year' do
      expect(described_class.parse_date_string('15/01/24', 'DD/MM/YY')).to eq(Date.new(2024, 1, 15))
    end
  end

  describe '.format_date_string' do
    it 'formats with explicit format' do
      expect(described_class.format_date_string('2024-01-15', 'DD/MM/YYYY', :en)).to eq('15/01/2024')
    end

    it 'falls back to US default for en-US locale' do
      expect(described_class.format_date_string('2024-01-15', nil, 'en-US')).to eq('01/15/2024')
    end

    it 'falls back to international default otherwise' do
      expect(described_class.format_date_string('2024-01-15', nil, :en)).to eq('15/01/2024')
    end

    it 'uppercases lowercase format strings' do
      expect(described_class.format_date_string('2024-01-15', 'dd/mm/yyyy', :en)).to eq('15/01/2024')
    end

    it 'returns the original string when unparseable' do
      expect(described_class.format_date_string('not-a-date', 'DD/MM/YYYY', :en)).to eq('not-a-date')
    end
  end
end
