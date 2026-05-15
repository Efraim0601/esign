# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpToken do
  describe '#set_sha256_and_token_prefix' do
    it 'fills sha256 and token prefix from token' do
      token = described_class.new(token: 'abcde12345')

      token.send(:set_sha256_and_token_prefix)

      expect(token.sha256).to eq(Digest::SHA256.hexdigest('abcde12345'))
      expect(token.token_prefix).to eq('abcde')
    end
  end
end
