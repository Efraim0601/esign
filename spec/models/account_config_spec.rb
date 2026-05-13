# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountConfig do
  it 'exposes expected default value lambdas' do
    expect(described_class::DEFAULT_VALUES[AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY]).to respond_to(:call)
    expect(described_class::DEFAULT_VALUES[AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY]).to respond_to(:call)
  end
end
