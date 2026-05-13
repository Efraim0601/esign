# frozen_string_literal: true

RSpec.describe TextUtils do
  describe '.rtl?' do
    it 'returns false for blank text' do
      expect(described_class.rtl?(nil)).to be false
      expect(described_class.rtl?('')).to be false
    end

    it 'returns false for plain latin text' do
      expect(described_class.rtl?('hello world')).to be false
    end

    it 'returns true for Hebrew text' do
      expect(described_class.rtl?('שלום')).to be true
    end

    it 'returns true for Arabic text' do
      expect(described_class.rtl?('مرحبا')).to be true
    end

    it 'returns false on encoding compatibility error' do
      bad = 'foo'.dup.force_encoding('ASCII-8BIT')
      allow(bad).to receive(:match?).and_raise(Encoding::CompatibilityError)
      expect(described_class.rtl?(bad)).to be false
    end
  end

  describe '.transliterate' do
    it 'converts accented characters to ASCII' do
      expect(described_class.transliterate('café')).to eq('cafe')
      expect(described_class.transliterate('naïve')).to eq('naive')
    end

    it 'returns input unchanged for plain ASCII' do
      expect(described_class.transliterate('hello')).to eq('hello')
    end

    it 'handles nil-to-string conversion' do
      expect(described_class.transliterate(nil)).to eq('')
    end
  end

  describe '.mask_value' do
    it 'masks the entire value when unmask_size is zero' do
      expect(described_class.mask_value('secret')).to eq('XXXXXX')
    end

    it 'preserves separator characters' do
      expect(described_class.mask_value('abc-def')).to eq('XXX-XXX')
      expect(described_class.mask_value('a.b,c (d) [e]')).to eq('X.X,X (X) [X]')
    end

    it 'unmasks the leading characters when unmask_size is positive' do
      expect(described_class.mask_value('abcdef', 2)).to eq('abXXXX')
    end

    it 'unmasks the trailing characters when unmask_size is negative' do
      expect(described_class.mask_value('abcdef', -2)).to eq('XXXXef')
    end

    it 'returns fully masked string when unmask_size >= length' do
      expect(described_class.mask_value('abc', 5)).to eq('XXX')
    end

    it 'accepts a custom mask symbol' do
      expect(described_class.mask_value('abcdef', 0, '*')).to eq('******')
    end
  end

  describe '.mask_email' do
    it 'returns the email unchanged when no @ is present' do
      expect(described_class.mask_email('not-an-email')).to eq('not-an-email')
    end

    it 'returns email unchanged when local or domain is blank' do
      expect(described_class.mask_email('@example.com')).to eq('@example.com')
      expect(described_class.mask_email('user@')).to eq('user@')
    end

    it 'masks the local part and the first domain segment, preserving punctuation' do
      expect(described_class.mask_email('john.doe@example.com')).to eq('jo**.***@e******.com')
    end

    it 'respects unmask_size parameter' do
      expect(described_class.mask_email('john@example.com', 1)).to eq('j***@e******.com')
    end
  end

  describe '.maybe_rtl_reverse' do
    it 'returns the input unchanged when no RTL chars' do
      expect(described_class.maybe_rtl_reverse('hello')).to eq('hello')
    end

    it 'reorders RTL text visually' do
      result = described_class.maybe_rtl_reverse('שלום')
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end
end
