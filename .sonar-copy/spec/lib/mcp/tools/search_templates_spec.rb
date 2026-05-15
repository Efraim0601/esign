# frozen_string_literal: true

RSpec.describe Mcp::Tools::SearchTemplates do
  describe '.call' do
    it 'returns template ids/names and defaults limit to 10 when invalid' do
      relation = double('relation')
      scoped = double('scoped')
      templates = [double('t1', id: 1, name: 'NDA')]

      allow(Template).to receive(:accessible_by).and_return(relation)
      allow(relation).to receive(:active).and_return(scoped)
      allow(Templates).to receive(:search).and_return(scoped)
      allow(scoped).to receive(:order).with(id: :desc).and_return(scoped)
      allow(scoped).to receive(:limit).with(10).and_return(templates)

      result = described_class.call({ 'q' => 'nda', 'limit' => 0 }, double('user'), double('ability'))

      expect(result[:content].first[:type]).to eq('text')
      expect(JSON.parse(result[:content].first[:text])).to eq([{ 'id' => 1, 'name' => 'NDA' }])
    end

    it 'caps limit at 100' do
      relation = double('relation')
      scoped = double('scoped')

      allow(Template).to receive(:accessible_by).and_return(relation)
      allow(relation).to receive(:active).and_return(scoped)
      allow(Templates).to receive(:search).and_return(scoped)
      allow(scoped).to receive(:order).with(id: :desc).and_return(scoped)
      allow(scoped).to receive(:limit).with(100).and_return([])

      described_class.call({ 'q' => 'nda', 'limit' => 999 }, double('user'), double('ability'))

      expect(scoped).to have_received(:limit).with(100)
    end
  end
end
