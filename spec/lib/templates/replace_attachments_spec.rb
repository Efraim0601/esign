# frozen_string_literal: true

RSpec.describe Templates::ReplaceAttachments do
  describe '.call' do
    it 'replaces schema uuids and remaps existing field areas' do
      template = OpenStruct.new(
        schema: [{ 'attachment_uuid' => 'old-1', 'name' => 'Old one' }],
        fields: [{ 'areas' => [{ 'attachment_uuid' => 'old-1' }] }],
        submitters: [{ 'uuid' => 'sub-1' }]
      )

      document = double('doc', uuid: 'new-1', filename: double(base: 'New one'), metadata: { 'pdf' => { 'fields' => [] } })
      allow(Templates::CreateAttachments).to receive(:call).and_return([[document], nil])

      docs = described_class.call(template, {}, extract_fields: false)

      expect(docs).to eq([document])
      expect(template.schema[0][:attachment_uuid]).to eq('new-1')
      expect(template.fields[0]['areas'][0]['attachment_uuid']).to eq('new-1')
    end

    it 'adds extracted pdf fields and marks first schema as pending' do
      template = OpenStruct.new(
        schema: [],
        fields: [],
        submitters: [{ 'uuid' => 'sub-1' }]
      )

      document = double(
        'doc',
        uuid: 'new-2',
        filename: double(base: 'Doc'),
        metadata: { 'pdf' => { 'fields' => [{ 'uuid' => 'f1', 'areas' => [] }] } }
      )
      allow(Templates::CreateAttachments).to receive(:call).and_return([[document], nil])

      described_class.call(template, {}, extract_fields: false)

      expect(template.fields.size).to eq(1)
      expect(template.fields.first['submitter_uuid']).to eq('sub-1')
      expect(template.schema[0]['pending_fields']).to be(true)
    end

  end

  describe '.replace_document_in_schema' do
    it 'remaps existing field areas to the new document uuid' do
      template = OpenStruct.new(
        schema: [{ 'attachment_uuid' => 'old', 'name' => 'Old' }],
        fields: [{ 'areas' => [{ 'attachment_uuid' => 'old' }, { 'attachment_uuid' => 'other' }] }]
      )
      document = double('doc', uuid: 'new', filename: double(base: 'New'))

      described_class.replace_document_in_schema(template, document, 0)

      expect(template.schema[0][:attachment_uuid]).to eq('new')
      expect(template.fields[0]['areas'][0]['attachment_uuid']).to eq('new')
      expect(template.fields[0]['areas'][1]['attachment_uuid']).to eq('other')
    end

    it 'sets schema entry even when no previous schema item exists' do
      template = OpenStruct.new(schema: [], fields: [])
      document = double('doc', uuid: 'first', filename: double(base: 'First'))

      described_class.replace_document_in_schema(template, document, 0)

      expect(template.schema[0][:attachment_uuid]).to eq('first')
    end

    it 'leaves blank-areas fields untouched' do
      template = OpenStruct.new(
        schema: [{ 'attachment_uuid' => 'old' }],
        fields: [{ 'areas' => nil }]
      )
      document = double('doc', uuid: 'new', filename: double(base: 'New'))

      expect { described_class.replace_document_in_schema(template, document, 0) }.not_to raise_error
    end
  end

  describe '.previous_document_has_anchored_field?' do
    it 'returns the field index when the previous doc has an anchor' do
      template = OpenStruct.new(
        schema: [{ attachment_uuid: 'doc-a' }, { attachment_uuid: 'doc-b' }],
        fields: [{ 'uuid' => 'f1', 'areas' => [{ 'attachment_uuid' => 'doc-a' }] }]
      )

      expect(described_class.previous_document_has_anchored_field?(template, 1)).to eq(0)
    end

    it 'returns false when no field references the previous doc uuid' do
      template = OpenStruct.new(
        schema: [{ attachment_uuid: 'doc-a' }, { attachment_uuid: 'doc-b' }],
        fields: [{ 'uuid' => 'f1', 'areas' => [{ 'attachment_uuid' => 'doc-z' }] }]
      )

      expect(described_class.previous_document_has_anchored_field?(template, 1)).to be(false)
    end
  end
end
