# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Template do
  describe '#application_key' do
    it 'returns external_id' do
      expect(described_class.new(external_id: 'tmp-ext').application_key).to eq('tmp-ext')
    end
  end

  describe '#link_form_fields' do
    it 'adds name when a field has {{name}} default value' do
      template = described_class.new(
        preferences: { 'link_form_fields' => ['email'] },
        fields: [{ 'default_value' => '{{name}}' }]
      )

      expect(template.link_form_fields).to include('name', 'email')
    end
  end
end
