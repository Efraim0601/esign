# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateSharing do
  it 'defines all-id constant for global sharing' do
    expect(described_class::ALL_ID).to eq(-1)
  end
end
