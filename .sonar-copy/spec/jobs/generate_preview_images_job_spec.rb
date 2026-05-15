# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeneratePreviewImagesJob do
  describe '#perform' do
    it 'loads attachment and generates preview images with bounded page range' do
      metadata = { 'pdf' => { 'number_of_pages' => 5 } }
      attachment = double('attachment', metadata: metadata)
      allow(attachment).to receive(:download).and_return('pdf-bytes')

      allow(ActiveStorage::Attachment).to receive(:find).with(9).and_return(attachment)
      stub_const('Templates::ProcessDocument::MAX_NUMBER_OF_PAGES_PROCESSED', 2)
      allow(Templates::ProcessDocument).to receive(:generate_document_preview_images)

      described_class.new.perform('attachment_id' => 9)

      expect(Templates::ProcessDocument).to have_received(:generate_document_preview_images).with(
        attachment, 'pdf-bytes', 1..2, concurrency: 1
      )
    end
  end
end
