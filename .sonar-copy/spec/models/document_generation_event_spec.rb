# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentGenerationEvent do
  it 'defines expected enum values for event_name' do
    expect(described_class.event_names.keys).to include('start', 'retry', 'complete', 'fail')
  end
end
