# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookEvent do
  it 'assigns a default uuid on initialization' do
    model = described_class.new

    expect(model.uuid).to be_present
  end
end
