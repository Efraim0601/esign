# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::GenerateFontImage do
  describe '.call' do
    it 'maps alias font name and returns png buffer' do
      text_image = double('text_image', width: 10, height: 5)
      mask = double('mask')
      banded = double('banded')
      copied = double('copied')

      allow(Vips::Image).to receive(:text).and_return(text_image)
      allow(Vips::Image).to receive(:black).with(10, 5).and_return(mask)
      allow(mask).to receive(:bandjoin).with(text_image).and_return(banded)
      allow(banded).to receive(:copy).with(interpretation: :b_w).and_return(copied)
      allow(copied).to receive(:write_to_buffer).with('.png').and_return('png-bytes')

      result = described_class.call('<b>A</b>', font: 'signature')

      expect(result).to eq('png-bytes')
      expect(Vips::Image).to have_received(:text).with(
        '&lt;b&gt;A&lt;/b&gt;',
        hash_including(font: 'Dancing Script Regular', fontfile: Submitters::GenerateFontImage::FONTS['Dancing Script Regular'])
      )
    end
  end
end
