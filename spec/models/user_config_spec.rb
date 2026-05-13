# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserConfig do
  it 'declares expected config key constants' do
    expect(described_class::SIGNATURE_KEY).to eq('signature')
    expect(described_class::INITIALS_KEY).to eq('initials')
    expect(described_class::SHOW_APP_TOUR).to eq('show_app_tour')
  end
end
