# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateAccess do
  it 'defines admin user id constant' do
    expect(described_class::ADMIN_USER_ID).to eq(-1)
  end
end
