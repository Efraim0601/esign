# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoleChangeLog do
  it 'validates presence of required attributes' do
    model = described_class.new

    expect(model.valid?).to be(false)
    expect(model.errors[:changed_by]).not_to be_empty
    expect(model.errors[:user_id]).not_to be_empty
  end
end
