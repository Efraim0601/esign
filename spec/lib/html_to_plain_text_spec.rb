# frozen_string_literal: true

RSpec.describe HtmlToPlainText do
  describe '.call' do
    it 'returns an empty string for blank input' do
      expect(described_class.call(nil)).to eq('')
      expect(described_class.call('   ')).to eq('')
    end

    it 'converts basic html blocks and links to readable text' do
      html = <<~HTML
        <div>Hello <strong>world</strong></div>
        <p>Read <a href="https://example.com/docs">the docs</a></p>
        <p><img alt="Logo" src="/logo.png"></p>
      HTML

      text = described_class.call(html, 80)

      expect(text).to include('Hello world')
      expect(text).to include('Read the docs ( https://example.com/docs )')
      expect(text).to include('Logo')
    end

    it 'ignores scripts and html comments and preserves line breaks' do
      html = <<~HTML
        <!-- start text/html -->ignored<!-- end text/html -->
        <p>Line 1<br>Line 2</p>
        <script>alert('x')</script>
      HTML

      text = described_class.call(html, 80)

      expect(text).to include("Line 1\nLine 2")
      expect(text).not_to include('ignored')
      expect(text).not_to include('alert')
    end

    it 'renders headings and list items' do
      html = <<~HTML
        <h1>Main title</h1>
        <h3>Section</h3>
        <ul><li>One</li><li>Two</li></ul>
      HTML

      text = described_class.call(html, 80)

      expect(text).to include('Main title')
      expect(text).to include('Section')
      expect(text).to include('* One')
      expect(text).to include('* Two')
    end

    it 'wraps long lines' do
      html = '<p>' + ('word ' * 40) + '</p>'

      text = described_class.call(html, 20)

      expect(text.lines.any? { |line| line.strip.length <= 20 }).to be(true)
    end
  end
end
