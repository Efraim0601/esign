# frozen_string_literal: true

RSpec.describe Submitters::MaybeAssignDefaultBrowserSignature do
  describe '.sign_signature_uuid and .verify_signature_uuid' do
    it 'delegates to signed id verifier with expected purpose' do
      verifier = double('verifier')
      allow(ApplicationRecord).to receive(:signed_id_verifier).and_return(verifier)
      allow(verifier).to receive(:generate).and_return('signed')
      allow(verifier).to receive(:verified).and_return('uuid-1')

      signed = described_class.sign_signature_uuid('uuid-1')
      value = described_class.verify_signature_uuid('signed')

      expect(signed).to eq('signed')
      expect(value).to eq('uuid-1')
    end
  end

  describe '.find_signature_from_uuid' do
    it 'returns nil when signature owner email does not match' do
      record = double('record', email: 'x@example.com')
      sig = double('sig', record: record)
      submitter = double('submitter', email: 'y@example.com')

      allow(ActiveStorage::Attachment).to receive(:find_by).with(uuid: 'u1').and_return(sig)

      expect(described_class.find_signature_from_uuid(submitter, 'u1', [])).to be_nil
    end
  end

  describe '.call' do
    it 'uses signature_src branch when provided' do
      submitter = double('submitter', id: 1)
      allow(described_class).to receive(:find_or_create_signature_from_value).and_return(:ok)

      result = described_class.call(submitter, { signature_src: 'data:image/png;base64,abcd' }, nil, [])

      expect(result).to eq(:ok)
      expect(described_class).to have_received(:find_or_create_signature_from_value)
    end

    it 'handles invalid json in cookies gracefully' do
      encrypted = { signature_uuids: '{invalid' }
      cookies = double('cookies', encrypted: encrypted)
      submitter = double('submitter', id: 1, email: 's@example.com')

      expect { described_class.call(submitter, {}, cookies, []) }.not_to raise_error
    end
  end
end
