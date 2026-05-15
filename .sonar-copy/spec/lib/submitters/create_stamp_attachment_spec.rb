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
  end
end
