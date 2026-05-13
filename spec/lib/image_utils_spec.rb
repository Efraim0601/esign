# frozen_string_literal: true

RSpec.describe ImageUtils do
  describe '.blank?' do
    it 'returns true for fully white image stats' do
      stats = double('stats')
      image = double('image', stats: stats, bands: 1)
      allow(stats).to receive(:getpoint).with(0, 0).and_return([255])
      allow(stats).to receive(:getpoint).with(1, 0).and_return([255])

      expect(described_class.blank?(image)).to be(true)
    end

    it 'returns false for non-uniform stats' do
      stats = double('stats')
      image = double('image', stats: stats, bands: 1)
      allow(stats).to receive(:getpoint).with(0, 0).and_return([10])
      allow(stats).to receive(:getpoint).with(1, 0).and_return([20])

      expect(described_class.blank?(image)).to be(false)
    end
  end

  describe '.error?' do
    it 'detects shifted error banner pattern' do
      cropped = double('cropped', to_a: [[1, 2, 3, 4, 5], [4, 5, 0, 0, 0]])
      image = double('image', width: 100)
      allow(image).to receive(:crop).and_return(cropped)

      expect(described_class.error?(image)).to be(true)
    end
  end
end
