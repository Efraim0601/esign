# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submission do
  describe '#expired?' do
    it 'is true when expire_at is in the past' do
      expect(described_class.new(expire_at: 1.hour.ago).expired?).to be(true)
    end

    it 'is false when expire_at is nil' do
      expect(described_class.new(expire_at: nil).expired?).to be_falsy
    end
  end

  describe '#audit_trail_url' do
    it 'returns nil when no audit trail is attached' do
      submission = described_class.new
      allow(submission).to receive(:audit_trail).and_return(nil)

      expect(submission.audit_trail_url).to be_nil
    end
  end
end
