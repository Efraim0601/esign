# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccessToken do
  it 'generates sha256 from token before validation' do
    token = build(:access_token, token: 'abc123')
    token.valid?
    expect(token.sha256).to eq(Digest::SHA256.hexdigest('abc123'))
  end

  it 'defaults token to base58 length 43' do
    token = build(:access_token)
    token.valid?
    expect(token.token.length).to eq(AccessToken::TOKEN_LENGTH)
  end
end

