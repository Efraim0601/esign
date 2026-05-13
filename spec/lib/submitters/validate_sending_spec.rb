# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::ValidateSending do
  describe '.call' do
    it 'returns true for a valid email' do
      submitter = double('submitter', email: 'user@example.test')

      expect(described_class.call(submitter, nil)).to be(true)
    end

    it 'raises InvalidEmail for malformed email' do
      submitter = double('submitter', email: 'invalid-email')

      expect { described_class.call(submitter, nil) }.to raise_error(Submitters::ValidateSending::InvalidEmail)
    end
  end
end
