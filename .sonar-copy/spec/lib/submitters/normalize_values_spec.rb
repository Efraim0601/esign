# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::NormalizeValues do
  describe '.normalize_value' do
    it 'normalizes checkbox values to booleans' do
      field = { 'type' => 'checkbox' }

      expect(described_class.normalize_value(field, 'YES')).to be(true)
      expect(described_class.normalize_value(field, '0')).to be(false)
    end

    it 'normalizes numeric values for number fields' do
      field = { 'type' => 'number' }

      expect(described_class.normalize_value(field, '12')).to eq(12)
      expect(described_class.normalize_value(field, '12.5')).to eq(12.5)
    end
  end

  describe '.normalize_date' do
    it 'parses unix timestamps and date strings' do
      field = { 'preferences' => { 'format' => 'dd/mm/yyyy' } }

      expect(described_class.normalize_date(field, 1_700_000_000)).to match(/\A\d{4}-\d{2}-\d{2}\z/)
      expect(described_class.normalize_date(field, '2026-05-11')).to eq('2026-05-11')
    end

    it 'returns original value when date parsing fails' do
      field = { 'preferences' => { 'format' => 'dd/mm/yyyy' } }

      expect(described_class.normalize_date(field, 'not-a-date')).to eq('not-a-date')
    end
  end

  describe '.fetch_fields' do
    let(:template) do
      double('template',
             submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
             fields: [{ 'uuid' => 'f1', 'submitter_uuid' => 's1' }])
    end

    it 'returns fields for a given submitter role' do
      fields = described_class.fetch_fields(template, submitter_name: 'Signer')

      expect(fields.map { |f| f['uuid'] }).to eq(['f1'])
    end

    it 'raises for unknown submitter role' do
      expect do
        described_class.fetch_fields(template, submitter_name: 'Unknown')
      end.to raise_error(Submitters::NormalizeValues::UnknownSubmitterName)
    end
  end

  describe '.fetch_roles_fields' do
    it 'returns fields scoped to multiple roles' do
      template = double('template',
                        submitters: [{ 'name' => 'A', 'uuid' => 'u1' }, { 'name' => 'B', 'uuid' => 'u2' }],
                        fields: [{ 'uuid' => 'f1', 'submitter_uuid' => 'u1' }, { 'uuid' => 'f2', 'submitter_uuid' => 'u2' }])

      fields = described_class.fetch_roles_fields(template, roles: %w[A B])

      expect(fields.map { |f| f['uuid'] }).to contain_exactly('f1', 'f2')
    end
  end

  describe '.build_fields_index' do
    it 'indexes fields by exact, parameterized and lowercased names' do
      fields = [{ 'name' => 'First Name', 'uuid' => 'u1' }]

      index = described_class.build_fields_index(fields)

      expect(index['First Name'].first['uuid']).to eq('u1')
      expect(index['first_name'].first['uuid']).to eq('u1')
      expect(index['first name'].first['uuid']).to eq('u1')
    end
  end

  describe '.normalize_attachment_value' do
    it 'deduplicates attachments by blob id for array values' do
      account = double('account')
      field = { 'type' => 'file' }
      att1 = double('att1', blob_id: 10, uuid: 'u1')
      att2 = double('att2', blob_id: 10, uuid: 'u2')

      allow(described_class).to receive(:find_or_build_attachment).and_return(att1, att2)

      uuids, attachments = described_class.normalize_attachment_value(['a', 'b'], field, account, [])

      expect(uuids).to eq(%w[u1 u2])
      expect(attachments.map(&:blob_id)).to eq([10, 10])
    end
  end

  describe '.find_or_build_attachment' do
    it 'raises on invalid default value payload' do
      field = { 'type' => 'file' }

      expect do
        described_class.find_or_build_attachment('not-a-url-or-base64', field, double('account'))
      end.to raise_error(Submitters::NormalizeValues::InvalidDefaultValue)
    end
  end

  describe '.find_or_create_blob_from_html' do
    it 'rejects html payloads for image defaults' do
      expect do
        described_class.find_or_create_blob_from_html(double('account'), '<html>x</html>', {})
      end.to raise_error(Submitters::NormalizeValues::InvalidDefaultValue, /HTML content is not allowed/)
    end
  end

  describe '.find_blob_by_checksum' do
    it 'returns blob when account owns submitter attachment records' do
      attachments_relation = double('attachments_relation')
      account_submitters = double('account_submitters')
      account = double('account', submitters: account_submitters)
      blob = double('blob', attachments: attachments_relation)

      allow(ActiveStorage::Blob).to receive(:find_by).with(checksum: 'chk').and_return(blob)
      allow(attachments_relation).to receive(:exists?).and_return(true)
      allow(attachments_relation).to receive(:where).with(record_type: 'Submitter').and_return(attachments_relation)
      allow(attachments_relation).to receive(:select).with(:record_id).and_return(:ids_query)
      allow(account_submitters).to receive(:exists?).with(id: :ids_query).and_return(true)

      expect(described_class.find_blob_by_checksum('chk', account)).to eq(blob)
    end
  end
end
