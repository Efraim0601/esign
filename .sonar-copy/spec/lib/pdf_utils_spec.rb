# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfUtils do
  describe '.encrypted?' do
    it 'returns false when pdf can be opened' do
      allow(HexaPDF::Document).to receive(:new).and_return(double('pdf'))

      expect(described_class.encrypted?('%PDF', password: nil)).to be(false)
    end

    it 'returns true on HexaPDF encryption error' do
      allow(HexaPDF::Document).to receive(:new).and_raise(HexaPDF::EncryptionError)

      expect(described_class.encrypted?('%PDF', password: 'x')).to be(true)
    end
  end

  describe '.decrypt' do
    it 'imports pages into decrypted document and returns bytes' do
      page = double('page')
      encrypted_doc = double('encrypted_doc', pages: [page])
      decrypted_pages = []
      decrypted_doc = double('decrypted_doc', pages: decrypted_pages)

      allow(HexaPDF::Document).to receive(:new).and_return(encrypted_doc, decrypted_doc)
      allow(decrypted_doc).to receive(:import).with(page).and_return(:imported_page)
      allow(decrypted_doc).to receive(:write) { |io, **| io.write('decrypted') }

      expect(described_class.decrypt('%PDF', 'pwd')).to eq('decrypted')
    end
  end
end
