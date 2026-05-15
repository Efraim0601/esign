# frozen_string_literal: true

RSpec.describe HighlightCode do
  describe '.call' do
    it 'highlights Ruby code with the default light theme' do
      result = described_class.call('def foo; 42; end', 'Ruby')
      expect(result).to be_a(String)
      expect(result).to include('foo')
      expect(result).to include('<span')
    end

    it 'highlights JavaScript code' do
      result = described_class.call('const x = 1;', 'Javascript')
      expect(result).to include('x')
      expect(result).to include('<span')
    end

    it 'strips the dark background color when using base16.dark' do
      result = described_class.call('puts 1', 'Ruby', theme: 'base16.dark')
      expect(result).not_to include('background-color: #181818')
    end
  end
end
