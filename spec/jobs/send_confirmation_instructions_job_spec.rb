# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendConfirmationInstructionsJob do
  describe '#perform' do
    it 'loads user and sends confirmation instructions' do
      user = double('user')
      allow(User).to receive(:find).with(11).and_return(user)
      allow(user).to receive(:send_confirmation_instructions)

      described_class.new.perform('user_id' => 11)

      expect(user).to have_received(:send_confirmation_instructions)
    end
  end
end
