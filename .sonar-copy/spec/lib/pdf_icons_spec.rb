# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfIcons do
  describe '.check_io' do
    it 'returns a StringIO built from check_data' do
      allow(described_class).to receive(:check_data).and_return('png-bytes')

      io = described_class.check_io

      expect(io).to be_a(StringIO)
      expect(io.read).to eq('png-bytes')
    end
  end

  describe '.logo_data' do
    it 'reads logo file from public path' do
      path = Pathname.new('/tmp/logo.png')
      allow(Rails).to receive(:root).and_return(Pathname.new('/tmp'))
      allow(path).to receive(:read).and_return('logo')
      allow(Pathname).to receive(:new).and_call_original
      allow(Rails.root).to receive(:join).with('public', 'logo.png').and_return(path)

      expect(described_class.logo_data).to eq('logo')
    end
  end
end
