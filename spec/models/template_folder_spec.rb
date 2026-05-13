# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateFolder do
  describe '#full_name' do
    it 'joins parent and child names when parent exists' do
      parent = double('parent', name: 'Parent')
      folder = described_class.new(name: 'Child', parent_folder: parent)
      allow(folder).to receive(:parent_folder_id?).and_return(true)

      expect(folder.full_name).to eq('Parent / Child')
    end
  end

  describe '#default?' do
    it 'is true when name equals default constant' do
      expect(described_class.new(name: TemplateFolder::DEFAULT_NAME).default?).to be(true)
    end
  end
end
