# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::ProcessDocument do
  describe '.normalize_attachment_fields' do
    it 'assigns first template submitter uuid to extracted pdf fields' do
      attachment = double('attachment', metadata: { 'pdf' => { 'fields' => [{ 'name' => 'A' }] } })
      template = double('template', submitters: [{ 'uuid' => 'u1' }])

      fields = described_class.normalize_attachment_fields(template, [attachment])

      expect(fields).to eq([{ 'name' => 'A', 'submitter_uuid' => 'u1' }])
    end
  end

  describe '.maybe_flatten_form' do
    it 'returns original data when pdf has no acro_form' do
      pdf = double('pdf', acro_form: nil)

      expect(described_class.maybe_flatten_form('pdf-data', pdf)).to eq('pdf-data')
    end
  end
end
