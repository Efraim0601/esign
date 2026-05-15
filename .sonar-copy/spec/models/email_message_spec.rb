# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailMessage do
  describe '#set_sha1' do
    it 'computes deterministic sha1 from subject and body' do
      message = described_class.new(subject: 'Hello', body: 'World')

      message.set_sha1

      expect(message.sha1).to eq(Digest::SHA1.hexdigest({ subject: 'Hello', body: 'World' }.to_json))
    end
  end
end
