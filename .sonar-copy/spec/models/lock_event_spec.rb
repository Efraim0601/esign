# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LockEvent do
  it 'defines expected event_name enum values' do
    expect(described_class.event_names.keys).to include('start', 'retry', 'complete', 'fail')
  end
end
