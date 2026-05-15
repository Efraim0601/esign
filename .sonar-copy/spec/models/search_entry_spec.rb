# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchEntry do
  it 'is an ActiveRecord model' do
    expect(described_class < ApplicationRecord).to be(true)
  end
end
