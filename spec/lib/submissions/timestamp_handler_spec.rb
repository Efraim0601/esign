# frozen_string_literal: true

RSpec.describe Submissions::TimestampHandler do
  describe '#initialize' do
    it 'splits primary and fallback TSA urls' do
      handler = described_class.new(tsa_url: 'https://a.test,https://b.test')

      expect(handler.tsa_url).to eq('https://a.test')
      expect(handler.tsa_fallback_url).to eq('https://b.test')
    end
  end

  describe '#finalize_objects' do
    it 'assigns timestamp signature metadata' do
      doc = double('doc', version: nil)
      signature = double('signature', document: doc)
      allow(doc).to receive(:version=)
      allow(signature).to receive(:[]=)

      described_class.new(tsa_url: 'https://a.test').finalize_objects(nil, signature)

      expect(signature).to have_received(:[]=).with(:Type, :DocTimeStamp)
      expect(signature).to have_received(:[]=).with(:Filter, :'Adobe.PPKLite')
      expect(signature).to have_received(:[]=).with(:SubFilter, :'ETSI.RFC3161')
      expect(doc).to have_received(:version=).with('2.0')
    end
  end

  describe '#build_payload' do
    it 'builds a DER encoded timestamp request' do
      payload = described_class.new(tsa_url: 'https://a.test').build_payload('abc')

      expect(payload).to be_a(String)
      expect(payload.bytesize).to be > 0
    end
  end

  describe '#sign' do
    it 'falls back to ASN1 generalized time on exception' do
      handler = described_class.new(tsa_url: 'https://a.test')
      io = StringIO.new('abcdef')
      allow(Faraday).to receive(:new).and_raise(StandardError, 'network')

      token = handler.sign(io, [0, 3, 3, 3])

      expect(token).to be_a(String)
      expect(token.bytesize).to be > 0
    end
  end
end
