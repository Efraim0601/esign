# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::SerializeForApi do
  describe '.serialize_events' do
    it 'serializes only supported event data keys' do
      event = double('event')
      allow(event).to receive(:as_json).with(only: %i[id submitter_id event_type event_timestamp]).and_return(
        'id' => 1, 'submitter_id' => 9, 'event_type' => 'send_email', 'event_timestamp' => 'x', 'data' => {}
      )
      allow(event).to receive(:data).and_return(
        'reason' => 'r',
        'firstname' => 'A',
        'lastname' => 'B',
        'method' => 'sms',
        'country' => 'FR',
        'idcode' => 'X',
        'ignored' => 'nope'
      )

      serialized = described_class.serialize_events([event])

      expect(serialized.first['data']).to eq(
        'reason' => 'r',
        'firstname' => 'A',
        'lastname' => 'B',
        'method' => 'sms',
        'country' => 'FR',
        'idcode' => 'X'
      )
    end
  end
end
