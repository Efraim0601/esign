# frozen_string_literal: true

RSpec.describe MarkdownToHtml do
  describe '.call' do
    it 'returns empty string for blank content' do
      expect(described_class.call(nil)).to eq('')
      expect(described_class.call('')).to eq('')
    end

    it 'auto-links plain urls and keeps trailing punctuation outside the link' do
      html = described_class.call('Visit https://example.com/path).')

      expect(html).to include('<a href="https://example.com/path">https://example.com/path</a>).')
    end

    it 'supports markdown formatting and sanitizes disallowed tags' do
      html = described_class.call("**bold** *italic* ++underlined++ `code` <script>alert(1)</script>")

      expect(html).to include('<strong>bold</strong>')
      expect(html).to include('<em>italic</em>')
      expect(html).to include('<u>underlined</u>')
      expect(html).to include('code')
      expect(html).not_to include('<script>')
    end

    it 'renders multi-paragraph content with line breaks' do
      markdown = "First line\nSecond line\n\nThird paragraph"
      html = described_class.call(markdown)

      expect(html).to include('<p>First line<br>Second line</p>')
      expect(html).to include('<p>Third paragraph</p>')
    end

    it 'preserves explicit markdown links without relinking them' do
      html = described_class.call('[Docs](https://example.com/docs)')

      expect(html).to include('<a href="https://example.com/docs">Docs</a>')
    end
  end
end
