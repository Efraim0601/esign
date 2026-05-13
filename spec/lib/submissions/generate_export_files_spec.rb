# frozen_string_literal: true

RSpec.describe Submissions::GenerateExportFiles do
  describe '.call' do
    it 'raises on unknown format' do
      allow(described_class).to receive(:build_table_rows).and_return([])

      expect { described_class.call([], format: :pdf) }.to raise_error(Submissions::GenerateExportFiles::UnknownFormat)
    end

    it 'delegates to rows_to_csv for csv format' do
      allow(described_class).to receive(:build_table_rows).and_return([[]])
      allow(described_class).to receive(:rows_to_csv).and_return('csv-data')

      expect(described_class.call([], format: :csv)).to eq('csv-data')
      expect(described_class).to have_received(:rows_to_csv)
    end

    it 'delegates to rows_to_xlsx for xlsx format' do
      allow(described_class).to receive(:build_table_rows).and_return([[]])
      allow(described_class).to receive(:rows_to_xlsx).and_return('xlsx-data')

      expect(described_class.call([], format: :xlsx)).to eq('xlsx-data')
      expect(described_class).to have_received(:rows_to_xlsx)
    end
  end

  describe '.rows_to_csv' do
    it 'exports headers and row values' do
      rows = [[{ name: 'Name', value: 'Alice' }, { name: 'Email', value: 'a@example.com' }]]

      csv = described_class.rows_to_csv(rows)

      expect(csv).to include('Name')
      expect(csv).to include('Email')
      expect(csv).to include('Alice')
      expect(csv).to include('a@example.com')
    end
  end

  describe '.rows_to_xlsx' do
    it 'builds xlsx content' do
      rows = [[{ name: 'Name', value: 'Alice' }]]

      xlsx = described_class.rows_to_xlsx(rows)

      expect(xlsx).to be_a(String)
      expect(xlsx.bytesize).to be > 0
    end
  end

  describe '.build_headers and .extract_columns' do
    it 'extracts all unique headers and aligns row values' do
      rows = [
        [{ name: 'A', value: 1 }, { name: 'B', value: 2 }],
        [{ name: 'B', value: 3 }, { name: 'C', value: 4 }]
      ]

      headers = described_class.build_headers(rows)
      values = described_class.extract_columns(rows.first, headers)

      expect(headers.to_a).to include('A', 'B', 'C')
      expect(values.size).to eq(headers.size)
      expect(values).to include(1, 2)
    end
  end

  describe '.column_name' do
    it 'prefixes with submitter name when multiple submitters' do
      expect(described_class.column_name('Email', 'Signer 1', 2)).to eq('Signer 1 - Email')
      expect(described_class.column_name('Email', 'Signer 1', 1)).to eq('Email')
    end
  end

  describe '.build_submission_data' do
    it 'includes link only for incomplete submitter' do
      submitter = double(
        'submitter',
        name: 'John',
        email: 'john@example.com',
        phone: '+1',
        status: 'pending',
        completed_at: nil,
        completed_at?: false,
        slug: 'abc'
      )

      routes = double('routes', submit_form_url: 'https://example.test/s/abc')
      allow(described_class).to receive(:r).and_return(routes)
      allow(Docuseal).to receive(:default_url_options).and_return({})

      data = described_class.build_submission_data(submitter, 'Signer', 2)

      expect(data.map { |e| e[:name] }).to include('Signer - Name', 'Signer - Link')
      expect(data.find { |e| e[:name].end_with?('Link') }[:value]).to eq('https://example.test/s/abc')
    end

    it 'omits link field when submitter is completed' do
      submitter = double(
        'submitter',
        name: 'John',
        email: 'john@example.com',
        phone: nil,
        status: 'completed',
        completed_at: Time.current,
        completed_at?: true,
        slug: 'abc'
      )

      data = described_class.build_submission_data(submitter, 'Signer', 1)

      expect(data.map { |e| e[:name] }).to include('Name', 'Email', 'Status')
      expect(data.map { |e| e[:name] }).not_to include('Link')
    end
  end

  describe '.submitter_formatted_fields' do
    it 'formats image and file fields as proxy urls' do
      blob1 = double('blob1')
      blob2 = double('blob2')
      att1 = double('att1', uuid: 'img-att', blob: blob1)
      att2 = double('att2', uuid: 'file-att', blob: blob2)
      submission = double('submission', template_fields: [
                            { 'uuid' => 'f1', 'type' => 'image', 'name' => 'Photo', 'submitter_uuid' => 's1' },
                            { 'uuid' => 'f2', 'type' => 'file', 'name' => 'Files', 'submitter_uuid' => 's1' }
                          ], template: double(fields: []))
      submitter = double('submitter', uuid: 's1', submission: submission, attachments: [att1, att2],
                                      values: { 'f1' => 'img-att', 'f2' => ['file-att'] })
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob1, expires_at: nil).and_return('https://files/img')
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(blob2, expires_at: nil).and_return('https://files/file')

      fields = described_class.submitter_formatted_fields(submitter)

      expect(fields.find { |f| f[:name] == 'Photo' }[:value]).to eq('https://files/img')
      expect(fields.find { |f| f[:name] == 'Files' }[:value]).to eq(['https://files/file'])
    end
  end
end
