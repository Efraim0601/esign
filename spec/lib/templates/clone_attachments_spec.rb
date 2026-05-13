# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::CloneAttachments do
  AttachmentCollection = Struct.new(:items) do
    def new(attrs = {})
      attrs = attrs.dup
      attrs[:preview_images_attachments] ||= AttachmentCollection.new([])
      attrs[:attachments_attachments] ||= AttachmentCollection.new([])
      obj = OpenStruct.new(attrs)
      items << obj
      obj
    end
  end

  TemplateStub = Struct.new(:schema, :fields, :documents_attachments, :dynamic_documents, :saved) do
    def save!
      self.saved = true
    end
  end

  it 'clones schema uuids, remaps field areas and duplicates preview attachments' do
    template = TemplateStub.new(
      schema: [{ 'attachment_uuid' => 'old-a', 'name' => 'Doc A' }],
      fields: [{ 'areas' => [{ 'attachment_uuid' => 'old-a' }] }],
      documents_attachments: AttachmentCollection.new([]),
      dynamic_documents: AttachmentCollection.new([]),
      saved: false
    )

    original_document = OpenStruct.new(
      uuid: 'old-a',
      blob_id: 11,
      preview_images_attachments: [OpenStruct.new(blob_id: 90)]
    )
    original_template = OpenStruct.new(
      schema_documents: [original_document],
      schema: [{ 'attachment_uuid' => 'old-a', 'dynamic' => false }],
      dynamic_documents: []
    )

    allow(SecureRandom).to receive(:uuid).and_return('new-a')

    attachments = described_class.call(
      template: template,
      original_template: original_template,
      documents: [{ 'name' => 'Renamed' }],
      excluded_attachment_uuids: [],
      save: true
    )

    expect(template.schema.first['attachment_uuid']).to eq('new-a')
    expect(template.schema.first['name']).to eq('Renamed')
    expect(template.fields.first['areas'].first['attachment_uuid']).to eq('new-a')
    expect(attachments.size).to eq(1)
    expect(attachments.first.uuid).to eq('new-a')
    expect(attachments.first.blob_id).to eq(11)
    expect(template.saved).to be(true)
  end

  it 'clones dynamic document and attached files when source schema is dynamic' do
    template = TemplateStub.new(
      schema: [{ 'attachment_uuid' => 'old-d' }],
      fields: [],
      documents_attachments: AttachmentCollection.new([]),
      dynamic_documents: AttachmentCollection.new([]),
      saved: false
    )

    source_dynamic = OpenStruct.new(
      uuid: 'old-d',
      body: 'body',
      head: 'head',
      attachments_attachments: [OpenStruct.new(uuid: 'da1', blob_id: 22)]
    )
    source_doc = OpenStruct.new(uuid: 'old-d', blob_id: 33, preview_images_attachments: [])

    original_template = OpenStruct.new(
      schema_documents: [source_doc],
      schema: [{ 'attachment_uuid' => 'old-d', 'dynamic' => true }],
      dynamic_documents: [source_dynamic]
    )

    allow(SecureRandom).to receive(:uuid).and_return('new-d')

    described_class.call(template: template, original_template: original_template, save: true)

    expect(template.dynamic_documents.items.size).to eq(1)
    new_dynamic = template.dynamic_documents.items.first
    expect(new_dynamic.uuid).to eq('new-d')
    expect(new_dynamic.body).to eq('body')
    expect(new_dynamic.head).to eq('head')
  end
end
