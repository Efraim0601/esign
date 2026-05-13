# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HtmlToPlainTextInterceptor do
  describe '.delivering_email' do
    it 'delegates to process' do
      message = Mail.new
      allow(described_class).to receive(:process).with(message).and_return(message)

      expect(described_class.delivering_email(message)).to eq(message)
    end
  end

  describe '.previewing_email' do
    it 'delegates to process' do
      message = Mail.new
      allow(described_class).to receive(:process).with(message).and_return(message)

      expect(described_class.previewing_email(message)).to eq(message)
    end
  end

  describe '.process' do
    it 'returns message unchanged when there is no html part' do
      message = Mail.new
      message.body = 'plain text'
      allow(message).to receive(:html_part).and_return(nil)

      expect(described_class.process(message)).to eq(message)
    end

    it 'adds text part for pure html message without text part' do
      message = Mail.new(content_type: 'text/html; charset=UTF-8')
      message.body = '<p>Hello <b>World</b></p>'
      allow(HtmlToPlainText).to receive(:call).and_return('Hello World')

      described_class.process(message)

      expect(message.content_type).to include('multipart/alternative')
      expect(message.parts.map(&:content_type).join(' ')).to include('text/plain', 'text/html')
    end

    it 'returns message unchanged when text part already exists' do
      message = Mail.new(content_type: 'multipart/alternative')
      message.text_part = Mail::Part.new(body: 'Already plain')
      message.html_part = Mail::Part.new(content_type: 'text/html; charset=UTF-8', body: '<p>Hello</p>')

      expect(described_class.process(message)).to eq(message)
    end

    it 'replaces html part inside multipart message with alternative part' do
      message = Mail.new(content_type: 'multipart/mixed')
      html = Mail::Part.new(content_type: 'text/html; charset=UTF-8', body: '<p>Hi</p>')
      message.add_part(html)
      allow(HtmlToPlainText).to receive(:call).and_return('Hi')

      described_class.process(message)

      expect(message.parts.first.content_type).to include('multipart/alternative')
      expect(message.parts.first.parts.map(&:content_type).join(' ')).to include('text/plain', 'text/html')
    end
  end

  describe '.replace_part' do
    it 'replaces nested old part recursively' do
      old_part = Mail::Part.new(content_type: 'text/html; charset=UTF-8', body: '<p>Old</p>')
      new_part = Mail::Part.new(content_type: 'multipart/alternative')
      container = Mail::Part.new(content_type: 'multipart/mixed')
      container.add_part(old_part)
      parts = [container]

      described_class.replace_part(parts, old_part, new_part)

      expect(container.parts).to include(new_part)
      expect(container.parts).not_to include(old_part)
    end
  end
end
