# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions do
  describe '.parse_emails' do
    it 'returns array input unchanged' do
      expect(described_class.parse_emails(%w[a@example.com b@example.com], nil)).to eq(%w[a@example.com b@example.com])
    end

    it 'extracts emails from free text' do
      text = 'a@example.com; b@example.com / c@example.com'
      result = described_class.parse_emails(text, nil)

      expect(result).to include('a@example.com', 'b@example.com', 'c@example.com')
    end
  end

  describe '.normalize_email' do
    it 'normalizes gmail typos ending with @gmail' do
      expect(described_class.normalize_email('User@GMAIL')).to eq('user@gmail.com')
    end

    it 'downcases addresses containing commas' do
      expect(described_class.normalize_email('A@EXAMPLE.COM,B@EXAMPLE.COM')).to eq('a@example.com,b@example.com')
    end

    it 'returns nil for blank or numeric values' do
      expect(described_class.normalize_email(nil)).to be_nil
      expect(described_class.normalize_email(123)).to be_nil
    end
  end

  describe '.check_item_conditions' do
    it 'returns true when no conditions are provided' do
      expect(described_class.check_item_conditions({ 'conditions' => [] }, {}, {})).to be(true)
    end

    it 'supports include_submitter_uuid shortcut and mixed OR logic' do
      item = {
        'conditions' => [
          { 'field_uuid' => 'f1', 'action' => 'not_empty' },
          { 'field_uuid' => 'f2', 'action' => 'not_empty', 'operation' => 'or' }
        ]
      }
      values = { 'f1' => '', 'f2' => '' }
      fields_index = {
        'f1' => { 'submitter_uuid' => 's1' },
        'f2' => { 'submitter_uuid' => 's2' }
      }

      # f1 is forced true via include_submitter_uuid, then OR with f2(false) => true
      expect(
        described_class.check_item_conditions(item, values, fields_index, include_submitter_uuid: 's1')
      ).to be(true)
    end
  end

  describe '.filtered_conditions_schema' do
    it 'filters schema items based on conditions results' do
      submission = double('submission')
      allow(submission).to receive(:template_schema).and_return([
                                                                  { 'attachment_uuid' => 'a1' },
                                                                  { 'attachment_uuid' => 'a2',
                                                                    'conditions' => [{ 'field_uuid' => 'f1', 'action' => 'not_empty' }] }
                                                                ])
      allow(submission).to receive(:template).and_return(double('template', schema: []))
      allow(submission).to receive(:fields_uuid_index).and_return({ 'f1' => { 'submitter_uuid' => 's2' } })
      allow(submission).to receive(:submitters).and_return([double('sub', values: { 'f1' => '' })])

      result = described_class.filtered_conditions_schema(submission)

      expect(result.map { |i| i['attachment_uuid'] }).to eq(['a1'])
    end
  end
end
