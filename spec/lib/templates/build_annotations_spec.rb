# frozen_string_literal: true

RSpec.describe Templates::BuildAnnotations do
  describe '.call' do
    it 'extracts only valid external link annotations' do
      box = double('box', width: 200.0, height: 400.0)
      page = double('page', box: box)
      valid = { Subtype: :Link, Rect: [20, 100, 80, 160], A: { URI: 'https://example.test' } }
      invalid = { Subtype: :Link, Rect: [0, 0, 10, 10], A: { URI: 'mailto:test@example.test' } }
      allow(page).to receive(:[]).with(:Annots).and_return([nil, 1, :x, valid, invalid])

      pdf = double('pdf', pages: [page])
      allow(HexaPDF::Document).to receive(:new).and_return(pdf)

      result = described_class.call('pdf-bytes')

      expect(result).to eq([
                             {
                               'type' => 'external_link',
                               'value' => 'https://example.test',
                               'x' => 0.1,
                               'y' => 0.6,
                               'w' => 0.3,
                               'h' => 0.15,
                               'page' => 0
                             }
                           ])
    end

    it 'returns empty array when parsing raises an error' do
      allow(HexaPDF::Document).to receive(:new).and_raise(StandardError, 'broken')

      expect(described_class.call('bad')).to eq([])
    end
  end

  describe '.build_external_link_hash' do
    it 'computes normalized annotation coordinates' do
      box = double('box', width: 100.0, height: 100.0)
      page = double('page', box: box)
      annot = { Rect: [10, 10, 40, 50], A: { URI: 'http://a.test' } }

      hash = described_class.build_external_link_hash(page, annot)

      expect(hash).to include(
        'type' => 'external_link',
        'value' => 'http://a.test',
        'x' => 0.1,
        'y' => 0.5,
        'w' => 0.3,
        'h' => 0.4
      )
    end
  end
end
