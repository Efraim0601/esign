# frozen_string_literal: true

RSpec.describe LoadBmp do
  describe '.parse_bmp_headers' do
    it 'rejects non bmp signatures' do
      bad = 'ZZ' + ("\x00" * 30)

      expect { described_class.parse_bmp_headers(bad) }.to raise_error(ArgumentError, /Not a valid BMP/)
    end

    it 'parses valid uncompressed 24-bit headers' do
      width = 2
      height = 2
      bpp = 24
      pixel_offset = 54
      info_header = [40, width, height, 1, bpp, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [pixel_offset].pack('L<') + info_header + ("\x00" * 16)

      data = described_class.parse_bmp_headers(bytes)

      expect(data[:width]).to eq(width)
      expect(data[:height]).to eq(height)
      expect(data[:bpp]).to eq(bpp)
      expect(data[:pixel_data_offset]).to eq(pixel_offset)
      expect(data[:orientation]).to eq(-1)
    end

    it 'rejects unsupported compression types' do
      info_header = [40, 2, 2, 1, 24, 1, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header + ("\x00" * 16)

      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /compression type/)
    end
  end

  describe '.decode_indexed_pixel_data' do
    it 'decodes 1-bit paletted data' do
      raw = "\x80\x00\x00\x00" # first pixel uses palette index 1, second uses 0 (with stride padding)
      palette = [[0, 0, 0], [255, 255, 255]]

      decoded = described_class.decode_indexed_pixel_data(raw, 1, 2, 1, 4, palette)

      expect(decoded.bytesize).to eq(6)
    end

    it 'decodes 8-bit paletted data' do
      raw = "\x01\x00\x00\x00"
      palette = [[0, 0, 0], [10, 20, 30]]

      decoded = described_class.decode_indexed_pixel_data(raw, 8, 1, 1, 4, palette)

      expect(decoded).to eq([10, 20, 30].pack('CCC'))
    end
  end

  describe '.call' do
    it 'builds an image and recombines channels for 24-bit bmp' do
      header = {
        width: 1, height: 1, bpp: 24, pixel_data_offset: 54, bmp_stride: 4, orientation: -1, color_table: nil
      }
      allow(described_class).to receive(:parse_bmp_headers).and_return(header)
      allow(described_class).to receive(:extract_raw_pixel_data_blob).and_return("\x00\x11\x22\x00")
      allow(described_class).to receive(:prepare_unpadded_pixel_data_string).and_return("\x00\x11\x22")

      rgb_image = double('rgb_image', interpretation: :srgb)
      flipped = double('flipped_image', recomb: rgb_image)
      image = double('source_image', flip: flipped)
      allow(Vips::Image).to receive(:new_from_memory).and_return(image)

      result = described_class.call('bmp')

      expect(result).to eq(rgb_image)
      expect(image).to have_received(:flip).with(:vertical)
    end
  end
end
