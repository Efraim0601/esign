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

    it 'rejects unsupported bpp values' do
      info_header = [40, 2, 2, 1, 16, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header + ("\x00" * 16)

      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /bits per pixel/)
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

    it 'decodes 4-bit paletted data' do
      raw = "\x12\x00\x00\x00"
      palette = [[0, 0, 0], [10, 10, 10], [20, 20, 20]]

      decoded = described_class.decode_indexed_pixel_data(raw, 4, 2, 1, 4, palette)

      expect(decoded.bytesize).to eq(6)
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

    it 'uses indexed decoding branch for 8-bit bmp' do
      header = {
        width: 1, height: 1, bpp: 8, pixel_data_offset: 54, bmp_stride: 4, orientation: 1, color_table: [[0, 0, 0]]
      }
      allow(described_class).to receive(:parse_bmp_headers).and_return(header)
      allow(described_class).to receive(:extract_raw_pixel_data_blob).and_return("\x00\x00\x00\x00")
      allow(described_class).to receive(:decode_indexed_pixel_data).and_return([0, 0, 0].pack('C*'))

      image = double('image', interpretation: :srgb)
      allow(Vips::Image).to receive(:new_from_memory).and_return(image)

      expect(described_class.call('bmp')).to eq(image)
      expect(described_class).to have_received(:decode_indexed_pixel_data)
    end

    it 'reinterprets image as srgb when source interpretation differs' do
      header = {
        width: 1, height: 1, bpp: 24, pixel_data_offset: 54, bmp_stride: 4, orientation: -1, color_table: nil
      }
      allow(described_class).to receive(:parse_bmp_headers).and_return(header)
      allow(described_class).to receive(:extract_raw_pixel_data_blob).and_return("\x00\x11\x22\x00")
      allow(described_class).to receive(:prepare_unpadded_pixel_data_string).and_return("\x00\x11\x22")

      copied_image = double('copied_image', interpretation: :srgb)
      cmyk_image = double('cmyk_image', interpretation: :cmyk)
      allow(cmyk_image).to receive(:copy).with(interpretation: :srgb).and_return(copied_image)
      flipped = double('flipped_image', recomb: cmyk_image)
      image = double('source_image', flip: flipped)
      allow(Vips::Image).to receive(:new_from_memory).and_return(image)

      expect(described_class.call('bmp')).to eq(copied_image)
    end

    it 'uses 32-bit recomb branch for 32-bit images' do
      header = {
        width: 1, height: 1, bpp: 32, pixel_data_offset: 54, bmp_stride: 4, orientation: 1, color_table: nil
      }
      allow(described_class).to receive(:parse_bmp_headers).and_return(header)
      allow(described_class).to receive(:extract_raw_pixel_data_blob).and_return("\x00\x11\x22\xff")
      allow(described_class).to receive(:prepare_unpadded_pixel_data_string).and_return("\x00\x11\x22\xff")

      rgb_image = double('rgb_image', interpretation: :srgb)
      image = double('source_image', recomb: rgb_image)
      allow(Vips::Image).to receive(:new_from_memory).and_return(image)

      expect(described_class.call('bmp')).to eq(rgb_image)
      expect(image).to have_received(:recomb)
    end
  end

  describe '.extract_raw_pixel_data_blob' do
    it 'raises when offset + size exceeds file' do
      expect do
        described_class.extract_raw_pixel_data_blob('abc', 10, 4, 3)
      end.to raise_error(ArgumentError, /exceeds BMP file size/)
    end

    it 'extracts pixel blob when data is sufficient' do
      payload = ("\x00" * 10) + ("\xff" * 16)

      blob = described_class.extract_raw_pixel_data_blob(payload, 10, 4, 4)

      expect(blob.bytesize).to eq(16)
    end
  end

  describe '.prepare_unpadded_pixel_data_string' do
    it 'strips row padding for 24-bit images' do
      # 2x2 image with 24bpp, stride padded to 8 bytes per row
      # Row data: [BGR][BGR][padding(2)] = 8 bytes per row
      raw = [
        0xAA, 0xBB, 0xCC, # pixel 1 (BGR)
        0x11, 0x22, 0x33, # pixel 2
        0x00, 0x00,       # padding
        0xDD, 0xEE, 0xFF, # row2 pixel 1
        0x44, 0x55, 0x66, # row2 pixel 2
        0x00, 0x00        # padding
      ].pack('C*')

      result = described_class.prepare_unpadded_pixel_data_string(raw, 24, 2, 2, 8)

      expect(result.bytesize).to eq(12) # 2 pixels * 3 bytes * 2 rows
    end

    it 'raises when blob is shorter than expected for a row' do
      raw = "\x00\x00\x00" # not enough bytes

      expect do
        described_class.prepare_unpadded_pixel_data_string(raw, 24, 2, 1, 8)
      end.to raise_error(ArgumentError, /Not enough data/)
    end
  end

  describe '.decode_indexed_pixel_data 4-bit and 1-bit' do
    it 'decodes 4-bit indexed pixel data' do
      raw = [0x12, 0x34].pack('C*') # 2 pixels (0x1, 0x2) on row 1
      palette = [[0, 0, 0], [10, 20, 30], [40, 50, 60]]

      result = described_class.decode_indexed_pixel_data(raw, 4, 2, 1, 4, palette)

      expect(result.bytesize).to eq(6)
      expect(result.bytes[0..2]).to eq([10, 20, 30])
      expect(result.bytes[3..5]).to eq([40, 50, 60])
    end

    it 'decodes 1-bit indexed pixel data' do
      raw = [0b10100000, 0, 0, 0].pack('C*')
      palette = [[0, 0, 0], [255, 255, 255]]

      result = described_class.decode_indexed_pixel_data(raw, 1, 3, 1, 4, palette)

      expect(result.bytesize).to eq(9)
      expect(result.bytes[0..2]).to eq([255, 255, 255])
      expect(result.bytes[3..5]).to eq([0, 0, 0])
      expect(result.bytes[6..8]).to eq([255, 255, 255])
    end
  end

  describe '.parse_bmp_headers more error cases' do
    it 'rejects too-short data for the file header' do
      expect { described_class.parse_bmp_headers('AB') }.to raise_error(ArgumentError, /file header/)
    end

    it 'rejects too-short data for info header size field' do
      bytes = 'BM' + ("\x00" * 8) + ([54].pack('L<'))
      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /info header size field|signature|info header/)
    end

    it 'rejects unsupported info header size' do
      info_header = [20, 1, 1, 1, 24, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header + ("\x00" * 16)
      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /Unsupported BMP info header size/)
    end

    it 'rejects zero or negative width' do
      info_header = [40, 0, 1, 1, 24, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header + ("\x00" * 16)
      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /BMP width must be positive/)
    end

    it 'rejects unsupported planes value' do
      info_header = [40, 2, 2, 2, 24, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header + ("\x00" * 16)
      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /Expected 1/)
    end

    it 'parses top-down orientation when height is negative' do
      info_header = [40, 1, -1, 1, 24, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header + ("\x00" * 16)

      data = described_class.parse_bmp_headers(bytes)

      expect(data[:orientation]).to eq(1)
      expect(data[:height]).to eq(1)
    end

    it 'parses color table for 8-bit images' do
      width = 1
      height = 1
      bpp = 8
      info_header_size = 40
      num_colors = 256
      color_table_size = num_colors * 4
      pixel_offset = 14 + info_header_size + color_table_size

      info_header = [info_header_size, width, height, 1, bpp, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      color_table = (0...num_colors).flat_map { |i| [i % 256, 0, 0, 0] }.pack('C*')
      bytes = 'BM' + [pixel_offset + 4].pack('L<') + "\x00\x00\x00\x00" + [pixel_offset].pack('L<') +
              info_header + color_table + ("\x00" * 4)

      data = described_class.parse_bmp_headers(bytes)

      expect(data[:bpp]).to eq(bpp)
      expect(data[:color_table].size).to eq(num_colors)
    end

    it 'rejects color table that exceeds data size' do
      info_header_size = 40
      width = 1
      height = 1
      bpp = 8
      info_header = [info_header_size, width, height, 1, bpp, 0, 0, 0, 0, 0, 0].pack('L<l<l<S<S<L<L<l<l<L<L<')
      bytes = 'BM' + [70].pack('L<') + "\x00\x00\x00\x00" + [54].pack('L<') + info_header
      # No color table provided

      expect { described_class.parse_bmp_headers(bytes) }.to raise_error(ArgumentError, /color table/)
    end
  end
end
