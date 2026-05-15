# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationRecord do
  it 'is an abstract primary record class' do
    expect(described_class.abstract_class?).to be(true)
  end
end
