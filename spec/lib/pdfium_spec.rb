# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pdfium do

  describe '.error_message' do
    it 'returns mapped message for known error code' do
      expect(described_class.error_message(Pdfium::FPDF_ERR_PASSWORD)).to include('Incorrect password')
    end

    it 'returns fallback message for unknown error code' do
      expect(described_class.error_message(999)).to eq('Unknown error code: 999')
    end
  end

  describe '.check_last_error' do
    it 'does not raise when last error is success' do
      allow(described_class).to receive(:FPDF_GetLastError).and_return(Pdfium::FPDF_ERR_SUCCESS)

      expect { described_class.check_last_error('ctx') }.not_to raise_error
    end
  end
end
