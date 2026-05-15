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
end
