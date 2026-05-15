# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::Tools::SendDocuments do
  describe '.call' do
    it 'returns error when template cannot be found' do
      current_ability = double('ability')
      current_user = double('user')
      scope = double('scope')
      allow(Template).to receive(:accessible_by).with(current_ability).and_return(scope)
      allow(scope).to receive(:find_by).with(id: 1).and_return(nil)

      result = described_class.call({ 'template_id' => 1, 'submitters' => [] }, current_user, current_ability)

      expect(result[:isError]).to be(true)
      expect(result[:content].first[:text]).to eq('Template not found')
    end

    it 'returns error when template has no fields' do
      current_ability = double('ability')
      current_user = double('user', account_id: 7)
      scope = double('scope')
      template = create(:template)
      template.update_column(:fields, [])

      allow(Template).to receive(:accessible_by).with(current_ability).and_return(scope)
      allow(scope).to receive(:find_by).with(id: 2).and_return(template)
      allow(current_ability).to receive(:authorize!)

      result = described_class.call({ 'template_id' => 2, 'submitters' => [] }, current_user, current_ability)

      expect(result[:isError]).to be(true)
      expect(result[:content].first[:text]).to eq('Template has no fields')
    end
  end
end
