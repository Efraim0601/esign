# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicDocumentVersion do
  it 'defaults areas to an empty array-like value' do
    model = described_class.new

    expect(model.areas).to eq([])
  end
end
