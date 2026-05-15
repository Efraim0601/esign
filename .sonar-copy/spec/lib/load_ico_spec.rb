# frozen_string_literal: true

RSpec.describe LoadIco do
  describe '.call' do
    it 'rejects invalid ico headers' do
      expect { described_class.call('bad') }.to raise_error(ArgumentError, LoadIco::UNABLE_TO_LOAD)
    end

    it 'selects the best icon entry and loads its image' do
      header = [0, 1, 2].pack('S<S<S<')
      entry1 = [16, 16, 0, 0, 1, 32, 4, 38].pack('CCCCS<S<L<L<')
      entry2 = [32, 32, 0, 0, 1, 24, 4, 42].pack('CCCCS<S<L<L<')
      ico = header + entry1 + entry2 + 'AAAA' + 'BBBB'

      allow(described_class).to receive(:load_image_entry).and_return(:image)

      result = described_class.call(ico)

      expect(result).to eq(:image)
      expect(described_class).to have_received(:load_image_entry).with('BBBB', 32, 32)
    end

    it 'raises when image data size does not match entry size' do
      header = [0, 1, 1].pack('S<S<S<')
      entry = [16, 16, 0, 0, 1, 32, 10, 22].pack('CCCCS<S<L<L<')
      ico = header + entry + 'AAAA'

      expect { described_class.call(ico) }.to raise_error(ArgumentError, LoadIco::UNABLE_TO_LOAD)
    end
  end

  describe '.load_image_entry' do
    it 'returns nil for unsupported dib headers' do
      data = [12].pack('L<') + ("\x00" * 8)

      expect(described_class.load_image_entry(data, 1, 1)).to be_nil
    end

    it 'builds a vips image for valid 32-bit dib payload' do
      dib_header = [40].pack('L<')
      dib_params = [1, 1, 1, 32, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      pixel = [10, 20, 30, 40].pack('C*') # BGRA
      payload = dib_header + dib_params + pixel

      vips_image = instance_double(Vips::Image)
      allow(Vips::Image).to receive(:new_from_memory).and_return(vips_image)

      result = described_class.load_image_entry(payload, 1, 1)

      expect(result).to eq(vips_image)
      expect(Vips::Image).to have_received(:new_from_memory).with([30, 20, 10, 40].pack('C*'), 1, 1, 4, :uchar)
    end
  end
end
