# frozen_string_literal: true

RSpec.describe Mcp::HandleRequest do
  describe '.call' do
    it 'returns initialize payload' do
      allow(Docuseal).to receive(:version).and_return('1.2.3')

      result = described_class.call({ 'method' => 'initialize', 'id' => 7 }, double('user'), double('ability'))

      expect(result[:jsonrpc]).to eq('2.0')
      expect(result[:id]).to eq(7)
      expect(result.dig(:result, :serverInfo, :version)).to eq('1.2.3')
    end

    it 'returns nil for initialized notification' do
      expect(described_class.call({ 'method' => 'notifications/initialized' }, nil, nil)).to be_nil
    end

    it 'returns tools list payload' do
      stub_const('Mcp::HandleRequest::TOOLS_SCHEMA', [{ name: 'x' }])

      result = described_class.call({ 'method' => 'tools/list', 'id' => 1 }, nil, nil)

      expect(result.dig(:result, :tools)).to eq([{ name: 'x' }])
    end

    it 'calls selected tool for tools/call' do
      tool = double('tool')
      allow(tool).to receive(:call).and_return({ content: [] })
      stub_const('Mcp::HandleRequest::TOOLS_INDEX', { 'search_templates' => tool })

      body = {
        'method' => 'tools/call',
        'id' => 42,
        'params' => { 'name' => 'search_templates', 'arguments' => { 'q' => 'nda' } }
      }

      result = described_class.call(body, :user, :ability)

      expect(tool).to have_received(:call).with({ 'q' => 'nda' }, :user, :ability)
      expect(result[:id]).to eq(42)
      expect(result[:result]).to eq({ content: [] })
    end

    it 'raises for unknown tool name' do
      stub_const('Mcp::HandleRequest::TOOLS_INDEX', {})
      body = { 'method' => 'tools/call', 'params' => { 'name' => 'unknown' } }

      expect { described_class.call(body, nil, nil) }.to raise_error(RuntimeError, /Unknown tool/)
    end

    it 'returns method not found error for unsupported methods' do
      result = described_class.call({ 'method' => 'nope', 'id' => 9 }, nil, nil)

      expect(result.dig(:error, :code)).to eq(-32_601)
      expect(result.dig(:error, :message)).to include('Method not found')
    end
  end
end
