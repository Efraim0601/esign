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

    it 'returns nil when ico entry width does not match dib width' do
      dib_header = [40].pack('L<')
      dib_params = [2, 1, 1, 32, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      payload = dib_header + dib_params + ([0, 0, 0, 255] * 2).pack('C*')

      expect(described_class.load_image_entry(payload, 1, 1)).to be_nil
    end

    it 'returns nil for unsupported compression' do
      dib_header = [40].pack('L<')
      dib_params = [1, 1, 1, 32, 3, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      payload = dib_header + dib_params + [0, 0, 0, 255].pack('C*')

      expect(described_class.load_image_entry(payload, 1, 1)).to be_nil
    end

    it 'returns nil when dib_planes is not one' do
      dib_header = [40].pack('L<')
      dib_params = [1, 1, 2, 32, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      payload = dib_header + dib_params + [0, 0, 0, 255].pack('C*')

      expect(described_class.load_image_entry(payload, 1, 1)).to be_nil
    end

    it 'returns nil for unsupported bpp value' do
      dib_header = [40].pack('L<')
      dib_params = [1, 1, 1, 16, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      payload = dib_header + dib_params + ([0] * 4).pack('C*')

      expect(described_class.load_image_entry(payload, 1, 1)).to be_nil
    end

    it 'builds vips image for 24-bit payload (no AND mask)' do
      dib_header = [40].pack('L<')
      dib_params = [1, 1, 1, 24, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      pixel = [50, 60, 70].pack('C*') + ([0] * 1).pack('C*') # BGR + padding to multiple of 4
      payload = dib_header + dib_params + pixel

      vips_image = instance_double(Vips::Image)
      allow(Vips::Image).to receive(:new_from_memory).and_return(vips_image)

      expect(described_class.load_image_entry(payload, 1, 1)).to eq(vips_image)
      expect(Vips::Image).to have_received(:new_from_memory).with([70, 60, 50, 255].pack('C*'), 1, 1, 4, :uchar)
    end

    it 'builds vips image for 8-bit indexed payload with palette' do
      dib_header = [40].pack('L<')
      dib_params = [1, 1, 1, 8, LoadIco::BI_RGB, 0, 0, 0, 1, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      palette = [11, 22, 33, 0].pack('C*') # BGRA palette entry for index 0
      pixel = [0, 0, 0, 0].pack('C*') # one pixel index 0, padded
      payload = dib_header + dib_params + palette + pixel

      vips_image = instance_double(Vips::Image)
      allow(Vips::Image).to receive(:new_from_memory).and_return(vips_image)

      expect(described_class.load_image_entry(payload, 1, 1)).to eq(vips_image)
      expect(Vips::Image).to have_received(:new_from_memory).with([33, 22, 11, 255].pack('C*'), 1, 1, 4, :uchar)
    end

    it 'applies AND mask for 24-bit payload with mask data' do
      dib_header = [40].pack('L<')
      # height_field = 2 means 1 pixel high image with AND mask (height*2)
      dib_params = [1, 2, 1, 24, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      xor_row = [10, 20, 30].pack('C*') + ([0] * 1).pack('C*') # BGR + padding
      and_row = [0x80].pack('C*') + ([0] * 3).pack('C*') # mask bit 1 -> transparent
      payload = dib_header + dib_params + xor_row + and_row

      vips_image = instance_double(Vips::Image)
      allow(Vips::Image).to receive(:new_from_memory).and_return(vips_image)

      expect(described_class.load_image_entry(payload, 1, 1)).to eq(vips_image)
      expect(Vips::Image).to have_received(:new_from_memory).with([30, 20, 10, 0].pack('C*'), 1, 1, 4, :uchar)
    end

    it 'returns nil when xor scanline is shorter than expected' do
      dib_header = [40].pack('L<')
      dib_params = [4, 1, 1, 24, LoadIco::BI_RGB, 0, 0, 0, 0, 0].pack('l<l<S<S<L<L<l<l<L<L<')
      payload = dib_header + dib_params + ([0] * 2).pack('C*') # not enough bytes

      expect(described_class.load_image_entry(payload, 4, 1)).to be_nil
    end
  end
end
