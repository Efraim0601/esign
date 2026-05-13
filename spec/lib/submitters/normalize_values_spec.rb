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

    it 'builds text-based signature attachment for short values' do
      account = double('account')
      field = { 'type' => 'signature' }
      blob = double('blob', id: 1)
      attachment = double('attachment')
      allow(described_class).to receive(:find_or_create_blob_from_text).and_return(blob)
      allow(ActiveStorage::Attachment).to receive(:new).with(blob: blob, name: 'attachments').and_return(attachment)

      result = described_class.find_or_build_attachment('John', field, account)

      expect(result).to eq(attachment)
      expect(described_class).to have_received(:find_or_create_blob_from_text).with(account, 'John', 'signature')
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

  describe '.call' do
    it 'raises on unknown field name when throw_errors is enabled' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [{ 'uuid' => 'f1', 'name' => 'Email', 'submitter_uuid' => 's1', 'type' => 'text' }])

      expect do
        described_class.call(template, { 'Unknown' => 'v' }, submitter_name: 'Signer', throw_errors: true)
      end.to raise_error(Submitters::NormalizeValues::UnknownFieldName)
    end

    it 'normalizes values using uuid-indexed fields' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [{ 'uuid' => 'f1', 'name' => 'Age', 'submitter_uuid' => 's1', 'type' => 'number' }])

      values, attachments, new_fields = described_class.call(template, { 'f1' => '42' }, submitter_name: 'Signer')

      expect(values).to eq({ 'f1' => 42 })
      expect(attachments).to eq([])
      expect(new_fields).to eq([])
    end

    it 'matches by parameterized name when uuid is not present' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [{ 'uuid' => 'f1', 'name' => 'Email Address',
                                   'submitter_uuid' => 's1', 'type' => 'text' }])

      values, = described_class.call(template, { 'email_address' => 'a@b.com' }, submitter_name: 'Signer')

      expect(values).to eq({ 'f1' => 'a@b.com' })
    end

    it 'silently skips unknown field when throw_errors is false' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [{ 'uuid' => 'f1', 'name' => 'Email', 'submitter_uuid' => 's1', 'type' => 'text' }])

      values, attachments, new_fields = described_class.call(template, { 'Unknown' => 'v' }, submitter_name: 'Signer')

      expect(values).to eq({})
      expect(attachments).to eq([])
      expect(new_fields).to eq([])
    end

    it 'skips blank keys without raising' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [])

      values, = described_class.call(template, { '' => 'v' }, submitter_name: 'Signer')

      expect(values).to eq({})
    end

    it 'falls back to for_submitter.submission.template_fields when supplied' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [])
      submitter = double('for_submitter',
                         uuid: 's1',
                         submission: double('submission',
                                            template_fields: [{ 'uuid' => 'f1', 'name' => 'Note',
                                                                'submitter_uuid' => 's1', 'type' => 'text' }]))

      values, = described_class.call(template, { 'f1' => 'hello' }, for_submitter: submitter)

      expect(values).to eq({ 'f1' => 'hello' })
    end

    it 'normalizes attachment values for image fields' do
      template = double('template',
                        submitters: [{ 'name' => 'Signer', 'uuid' => 's1' }],
                        fields: [{ 'uuid' => 'f1', 'name' => 'Sig', 'submitter_uuid' => 's1', 'type' => 'signature' }],
                        account: double('account'))
      attachment = double('attachment', uuid: 'att-1', blob_id: 11)
      allow(described_class).to receive(:find_or_build_attachment).and_return(attachment)

      values, attachments = described_class.call(template, { 'f1' => 'John' }, submitter_name: 'Signer')

      expect(values).to eq({ 'f1' => 'att-1' })
      expect(attachments).to eq([attachment])
    end
  end

  describe '.normalize_value default branches' do
    it 'returns nil for blank text values' do
      expect(described_class.normalize_value({ 'type' => 'text' }, '')).to be_nil
    end

    it 'coerces text values to string' do
      expect(described_class.normalize_value({ 'type' => 'text' }, 42)).to eq('42')
    end

    it 'returns original token when date value is {{date}} placeholder' do
      expect(described_class.normalize_value({ 'type' => 'date' }, '{{date}}')).to eq('{{date}}')
    end

    it 'returns value unchanged for unknown field types' do
      expect(described_class.normalize_value({ 'type' => 'custom' }, 'whatever')).to eq('whatever')
    end
  end

  describe '.normalize_date with format string' do
    it 'parses using template preference format when format placeholder matches' do
      field = { 'preferences' => { 'format' => 'dd/mm/yyyy' } }
      allow(TimeUtils).to receive(:parse_date_string).with('11/05/2026', 'dd/mm/yyyy').and_return(Date.new(2026, 5, 11))

      expect(described_class.normalize_date(field, '11/05/2026')).to eq('2026-05-11')
    end
  end

  describe '.find_or_build_attachment for url and base64' do
    let(:account) { double('account') }

    it 'creates blob from URL when value is HTTPS url' do
      field = { 'type' => 'file' }
      blob = double('blob', id: 1)
      allow(described_class).to receive(:find_or_create_blob_from_url).and_return(blob)
      attachment = double('attachment')
      allow(ActiveStorage::Attachment).to receive(:new).with(blob: blob, name: 'attachments').and_return(attachment)

      expect(described_class.find_or_build_attachment('https://files.test/a.png', field, account)).to eq(attachment)
    end

    it 'creates blob from base64 when content is recognizable' do
      png = "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01" \
            "\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01" \
            "\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
      data = Base64.strict_encode64(png.b)
      field = { 'type' => 'image' }
      blob = double('blob', id: 7)
      allow(described_class).to receive(:find_or_create_blob_from_base64).and_return(blob)
      attachment = double('attachment')
      allow(ActiveStorage::Attachment).to receive(:new).with(blob: blob, name: 'attachments').and_return(attachment)

      expect(described_class.find_or_build_attachment(data, field, account)).to eq(attachment)
    end

    it 'reuses existing attachment for given submitter when blob already attached' do
      field = { 'type' => 'signature' }
      blob = double('blob', id: 1)
      existing_attachment = double('existing')
      attachments_relation = double('attachments')
      submitter = double('for_submitter', attachments: attachments_relation)
      allow(attachments_relation).to receive(:find_by).with(blob_id: 1).and_return(existing_attachment)
      allow(described_class).to receive(:find_or_create_blob_from_text).and_return(blob)

      expect(described_class.find_or_build_attachment('Sig', field, double('account'), submitter)).to eq(existing_attachment)
    end
  end

  describe '.find_or_create_blob_from_text' do
    it 'returns cached blob if one exists for account with matching checksum' do
      account = double('account')
      blob = double('blob')
      allow(Submitters::GenerateFontImage).to receive(:call).with('John', font: 'signature').and_return('img-data')
      allow(described_class).to receive(:find_blob_by_checksum).and_return(blob)

      expect(described_class.find_or_create_blob_from_text(account, 'John', 'signature')).to eq(blob)
    end

    it 'creates a new blob when none is cached' do
      account = double('account')
      created = double('created_blob')
      allow(Submitters::GenerateFontImage).to receive(:call).with('John', font: 'initials').and_return('img-data')
      allow(described_class).to receive(:find_blob_by_checksum).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(created)

      expect(described_class.find_or_create_blob_from_text(account, 'John', 'initials')).to eq(created)
    end
  end

  describe '.find_or_create_blob_from_base64' do
    it 'creates a new blob when none is cached' do
      account = double('account')
      data = 'binary-data'
      created = double('blob')
      allow(described_class).to receive(:find_blob_by_checksum).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(created)

      expect(described_class.find_or_create_blob_from_base64(account, data, 'image')).to eq(created)
    end
  end

  describe '.find_or_create_blob_from_url' do
    it 'reuses cached checksum lookup when available' do
      account = double('account', id: 1)
      url = 'https://files.test/x.png'
      blob = double('blob')

      described_class::CHECKSUM_CACHE_STORE.write([account.id, url].join(':'), 'cached_checksum')
      allow(described_class).to receive(:find_blob_by_checksum).with('cached_checksum', account).and_return(blob)

      expect(described_class.find_or_create_blob_from_url(account, url)).to eq(blob)
    end

    it 'downloads remote content and creates new blob when missing' do
      account = double('account', id: 2)
      url = 'https://files.test/y.png'
      response = double('response', body: 'png-data')
      blob = double('blob')

      described_class::CHECKSUM_CACHE_STORE.delete([account.id, url].join(':'))
      allow(DownloadUtils).to receive(:call).with(url, validate: true).and_return(response)
      allow(described_class).to receive(:find_blob_by_checksum).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)

      expect(described_class.find_or_create_blob_from_url(account, url)).to eq(blob)
    end
  end

  describe '.find_blob_by_checksum' do
    it 'returns nil when blob is not found' do
      allow(ActiveStorage::Blob).to receive(:find_by).with(checksum: 'x').and_return(nil)

      expect(described_class.find_blob_by_checksum('x', double('account'))).to be_nil
    end

    it 'returns blob when it has no attachments yet' do
      attachments_relation = double('attachments_relation')
      blob = double('blob', attachments: attachments_relation)
      allow(ActiveStorage::Blob).to receive(:find_by).with(checksum: 'y').and_return(blob)
      allow(attachments_relation).to receive(:exists?).and_return(false)

      expect(described_class.find_blob_by_checksum('y', double('account'))).to eq(blob)
    end

    it 'returns nil when blob is attached to a different account' do
      attachments_relation = double('attachments_relation')
      account_submitters = double('account_submitters')
      account = double('account', submitters: account_submitters)
      blob = double('blob', attachments: attachments_relation)
      allow(ActiveStorage::Blob).to receive(:find_by).with(checksum: 'z').and_return(blob)
      allow(attachments_relation).to receive(:exists?).and_return(true)
      allow(attachments_relation).to receive(:where).with(record_type: 'Submitter').and_return(attachments_relation)
      allow(attachments_relation).to receive(:select).with(:record_id).and_return(:ids_query)
      allow(account_submitters).to receive(:exists?).with(id: :ids_query).and_return(false)

      expect(described_class.find_blob_by_checksum('z', account)).to be_nil
    end
  end
end
