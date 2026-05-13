# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicDocument do
  describe '#set_sha1' do
    it 'computes sha1 from body' do
      model = described_class.new(body: 'dynamic body')

      model.set_sha1

      expect(model.sha1).to eq(Digest::SHA1.hexdigest('dynamic body'))
    end
  end
end
