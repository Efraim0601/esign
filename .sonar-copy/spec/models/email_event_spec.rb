# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailEvent do
  describe '#maybe_set_account' do
    it 'copies account from emailable when missing' do
      account = double('account')
      emailable = double('emailable', account: account)
      event = described_class.new
      allow(event).to receive(:emailable).and_return(emailable)

      event.maybe_set_account

      expect(event.account).to eq(account)
    end
  end
end
