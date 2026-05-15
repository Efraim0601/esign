# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EncryptedConfig do
  it 'contains expected config keys' do
    expect(described_class::CONFIG_KEYS).to include(
      EncryptedConfig::EMAIL_SMTP_KEY,
      EncryptedConfig::ESIGN_CERTS_KEY,
      EncryptedConfig::APP_URL_KEY
    )
  end
end
