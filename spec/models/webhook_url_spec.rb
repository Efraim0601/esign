# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookUrl do
  describe '#set_sha1' do
    it 'sets sha1 from url value' do
      model = described_class.new(url: 'https://example.test/hook')

      model.set_sha1

      expect(model.sha1).to eq(Digest::SHA1.hexdigest('https://example.test/hook'))
    end
  end

  it 'contains expected event names' do
    expect(described_class::EVENTS).to include('form.completed', 'submission.created', 'template.updated')
  end
end
