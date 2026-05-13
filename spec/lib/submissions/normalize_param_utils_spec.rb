# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::NormalizeParamUtils do
  describe '.normalize_submitter_params!' do
    it 'normalizes values via Submitters::NormalizeValues and writes back values' do
      template = double('template', submitters: [{ 'name' => 'Signer', 'uuid' => 'u1' }])
      params = { role: 'Signer', values: { name: 'Alice' } }

      allow(Submitters::NormalizeValues).to receive(:call).and_return([{ 'f1' => 'v1' }, [:a], [:f]])

      normalized, attachments, fields = described_class.normalize_submitter_params!(params, template, 0)

      expect(normalized[:values]).to eq({ 'f1' => 'v1' })
      expect(attachments).to eq([:a])
      expect(fields).to eq([:f])
    end
  end

  describe '.save_default_value_attachments!' do
    it 'attaches matching default attachments to submitters and saves them' do
      attachment = double('attachment', uuid: 'att-1')
      allow(attachment).to receive(:record=)
      allow(attachment).to receive(:save!)
      submitter = double('submitter', values: { 'f1' => 'att-1' })

      described_class.save_default_value_attachments!([attachment], [submitter])

      expect(attachment).to have_received(:record=).with(submitter)
      expect(attachment).to have_received(:save!)
    end
  end
end
