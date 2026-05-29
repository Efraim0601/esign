# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateFolder do
  describe '#full_name' do
    it 'joins parent and child names when parent exists' do
      parent = instance_double(described_class, name: 'Parent')
      folder = described_class.new(name: 'Child')
      allow(folder).to receive_messages(parent_folder_id?: true, parent_folder: parent)

      expect(folder.full_name).to eq('Parent / Child')
    end
  end

  describe '#default?' do
    it 'is true when name equals default constant' do
      expect(described_class.new(name: TemplateFolder::DEFAULT_NAME).default?).to be(true)
    end
  end
end
