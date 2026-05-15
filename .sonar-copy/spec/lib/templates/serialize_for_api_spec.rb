# frozen_string_literal: true

RSpec.describe Templates::SerializeForApi do
  describe '.call' do
    it 'serializes schema documents with urls and preview urls' do
      attachment_blob = double('attachment_blob')
      preview_blob = double('preview_blob')
      preview_attachment = double('preview_attachment', record_id: 10, blob: preview_blob)
      attachment = double('attachment',
                          id: 10,
                          uuid: 'a1',
                          blob: attachment_blob,
                          filename: 'file.pdf',
                          preview_images: double('preview_images'))
      template = double('template',
                        account_id: 1,
                        schema: [{ 'attachment_uuid' => 'a1' }],
                        as_json: { 'id' => 1 })

      allow(attachment).to receive(:preview_images).and_return(double('imgs'))
      allow(attachment.preview_images).to receive(:joins).with(:blob).and_return(attachment.preview_images)
      allow(attachment.preview_images).to receive(:find_by).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(attachment_blob, expires_at: 123).and_return('doc-url')
      allow(ActiveStorage::Blob).to receive(:proxy_url).with(preview_blob, expires_at: 123).and_return('preview-url')

      json = described_class.call(template,
                                  schema_documents: [attachment],
                                  preview_image_attachments: [preview_attachment],
                                  expires_at: 123)

      expect(json['documents']).to eq([
                                       {
                                         'id' => 10,
                                         'uuid' => 'a1',
                                         'url' => 'doc-url',
                                         'preview_image_url' => 'preview-url',
                                         'filename' => 'file.pdf'
                                       }
                                     ])
    end

    it 'skips missing attachments from schema' do
      template = double('template', account_id: 1, schema: [{ 'attachment_uuid' => 'missing' }], as_json: {})

      json = described_class.call(template, schema_documents: [], preview_image_attachments: [], expires_at: 1)

      expect(json['documents']).to eq([])
    end
  end
end
