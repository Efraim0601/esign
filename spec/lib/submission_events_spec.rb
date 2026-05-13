# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmissionEvents do
  describe '.build_tracking_param' do
    it 'returns deterministic short tracking token for same submitter and event' do
      submitter = double('submitter', slug: 'slug-1')
      allow(Rails.application).to receive(:secret_key_base).and_return('secret')

      token1 = described_class.build_tracking_param(submitter, 'click_email')
      token2 = described_class.build_tracking_param(submitter, 'click_email')

      expect(token1).to eq(token2)
      expect(token1.length).to eq(SubmissionEvents::TRACKING_PARAM_LENGTH)
    end
  end

  describe '.create_with_tracking_data' do
    it 'creates event with request metadata and custom data' do
      submitter = double('submitter')
      session = double('session', id: 'sid-1')
      warden = double('warden', user: double('user', id: 9))
      request = double('request', remote_ip: '203.0.113.7', user_agent: 'UA', session: session, env: { 'warden' => warden })

      allow(SubmissionEvent).to receive(:create!)

      described_class.create_with_tracking_data(submitter, 'view_form', request, extra: 'x')

      expect(SubmissionEvent).to have_received(:create!).with(hash_including(
        submitter: submitter,
        event_type: 'view_form',
        data: hash_including(ip: '203.0.113.7', ua: 'UA', sid: 'sid-1', uid: 9, extra: 'x')
      ))
    end
  end
end
