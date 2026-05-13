# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::CreateStampAttachment do
  describe '.call' do
    it 'builds and saves attachment' do
      submitter = double('submitter')
      attachment = double('attachment')
      allow(attachment).to receive(:save!)
      allow(described_class).to receive(:build_attachment).with(submitter, with_logo: false).and_return(attachment)

      result = described_class.call(submitter, with_logo: false)

      expect(result).to eq(attachment)
      expect(attachment).to have_received(:save!)
    end
  end

  describe '.build_attachment' do
    it 'returns existing attachment when checksum matches' do
      image = double('image', width: 100, height: 50)
      allow(image).to receive(:write_to_buffer).with('.png').and_return('png-data')
      allow(described_class).to receive(:generate_stamp_image).and_return(image)

      relation = double('relation')
      existing = double('attachment')
      submitter = double('submitter', attachments: relation)
      allow(relation).to receive(:joins).with(:blob).and_return(relation)
      allow(relation).to receive(:find_by).and_return(existing)

      expect(described_class.build_attachment(submitter)).to eq(existing)
    end

    it 'builds a new attachment when no checksum match exists' do
      image = double('image', width: 200, height: 100)
      allow(image).to receive(:write_to_buffer).with('.png').and_return('new-png-data')
      allow(described_class).to receive(:generate_stamp_image).and_return(image)

      relation = double('relation')
      new_relation = double('new_relation')
      submitter = double('submitter', attachments: relation, attachments_attachments: new_relation)
      blob = double('blob')
      built_attachment = double('built_attachment')

      allow(relation).to receive(:joins).with(:blob).and_return(relation)
      allow(relation).to receive(:find_by).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
      allow(new_relation).to receive(:new).and_return(built_attachment)

      result = described_class.build_attachment(submitter, with_logo: false)

      expect(result).to eq(built_attachment)
      expect(ActiveStorage::Blob).to have_received(:create_and_upload!)
      expect(new_relation).to have_received(:new).with(hash_including(blob: blob, metadata: hash_including(width: 200)))
    end
  end

  describe '.generate_stamp_image' do
    it 'uses transparent pixel when logo is disabled' do
      logo = double('logo', width: 1, height: 1)
      resized_logo = double('resized_logo', width: 10, height: 10)
      base = double('base')
      final = double('final')
      opacity = double('opacity')

      allow(Vips::Image).to receive(:new_from_buffer).and_return(logo, opacity)
      allow(logo).to receive(:resize).and_return(resized_logo)
      allow(resized_logo).to receive(:resize).and_return(resized_logo)
      allow(opacity).to receive(:resize).and_return(opacity)
      allow(Vips::Image).to receive_message_chain(:black, :new_from_image, :copy).and_return(base)
      allow(base).to receive(:composite).and_return(base, final)

      result = described_class.generate_stamp_image(double('submitter'), with_logo: false)

      expect(result).to eq(final)
      expect(Vips::Image).to have_received(:new_from_buffer).with(described_class::TRANSPARENT_PIXEL, '').at_least(:once)
    end
  end
end
