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

    it 'uses storage branch when signed_signature_uuids provided' do
      submitter = double('submitter', id: 1, email: 'a@example.com')
      allow(described_class).to receive(:find_storage_signature).and_return(:storage)

      result = described_class.call(submitter,
                                    { signed_signature_uuids: { 'a@example.com' => 'signed-uuid' } },
                                    nil, [])

      expect(result).to eq(:storage)
    end

    it 'uses session cookie branch when no params provided' do
      submitter = double('submitter', id: 1, email: 'a@example.com')
      cookies = double('cookies', encrypted: { signature_uuids: { 'a@example.com' => 'u1' }.to_json })
      allow(described_class).to receive(:find_session_signature).and_return(:cookie)

      result = described_class.call(submitter, {}, cookies, [])

      expect(result).to eq(:cookie)
    end

    it 'falls back to signature param when signature_src is blank' do
      submitter = double('submitter', id: 1)
      allow(described_class).to receive(:find_or_create_signature_from_value).and_return(:ok)

      described_class.call(submitter, { signature: 'some-value' }, nil, [])

      expect(described_class).to have_received(:find_or_create_signature_from_value)
        .with(submitter, 'some-value', anything)
    end

    it 'returns nil when no signature source matches' do
      submitter = double('submitter', id: 1)
      expect(described_class.call(submitter, {}, nil, [])).to be_nil
    end

    it 'filters attachments to those owned by current submitter' do
      submitter = double('submitter', id: 7)
      other = double('att1', record_id: 99, record_type: 'Submitter')
      own = double('att2', record_id: 7, record_type: 'Submitter')
      different = double('att3', record_id: 7, record_type: 'Submission')
      allow(described_class).to receive(:find_or_create_signature_from_value) do |_, _, atts|
        @captured = atts
        :ok
      end

      described_class.call(submitter, { signature_src: 'foo' }, nil, [other, own, different])

      expect(@captured).to eq([own])
    end
  end

  describe '.find_or_create_signature_from_value' do
    it 'sets submitter as record and saves attachment' do
      submitter = double('submitter', account: double('account'))
      attachment = double('attachment', record: nil)
      allow(attachment).to receive(:record=)
      allow(attachment).to receive(:save!)
      allow(Submitters::NormalizeValues).to receive(:normalize_attachment_value)
        .and_return([nil, attachment])

      result = described_class.find_or_create_signature_from_value(submitter, 'value', [])

      expect(result).to eq(attachment)
      expect(attachment).to have_received(:record=).with(submitter)
      expect(attachment).to have_received(:save!)
    end

    it 'preserves existing attachment record when already set' do
      submitter = double('submitter', account: double('account'))
      existing_record = double('existing')
      attachment = double('attachment', record: existing_record)
      allow(attachment).to receive(:save!)
      allow(Submitters::NormalizeValues).to receive(:normalize_attachment_value)
        .and_return([nil, attachment])

      described_class.find_or_create_signature_from_value(submitter, 'value', [])

      expect(attachment).not_to receive(:record=)
      expect(attachment).to have_received(:save!)
    end
  end

  describe '.find_storage_signature' do
    it 'returns nil when signed uuid for submitter email is blank' do
      submitter = double('submitter', email: 'a@example.com')

      expect(described_class.find_storage_signature(submitter, {}, [])).to be_nil
    end

    it 'delegates to find_signature_from_uuid when verification succeeds' do
      submitter = double('submitter', email: 'a@example.com')
      allow(described_class).to receive(:verify_signature_uuid).with('signed').and_return('uuid-1')
      allow(described_class).to receive(:find_signature_from_uuid).and_return(:found)

      expect(described_class.find_storage_signature(submitter,
                                                    { 'a@example.com' => 'signed' }, [])).to eq(:found)
    end

    it 'returns nil when verification fails' do
      submitter = double('submitter', email: 'a@example.com')
      allow(described_class).to receive(:verify_signature_uuid).and_return(nil)

      expect(described_class.find_storage_signature(submitter,
                                                    { 'a@example.com' => 'signed' }, [])).to be_nil
    end
  end

  describe '.find_session_signature' do
    it 'parses cookie json and delegates to find_signature_from_uuid' do
      submitter = double('submitter', email: 'a@example.com')
      cookies = double('cookies', encrypted: { signature_uuids: { 'a@example.com' => 'uuid-1' }.to_json })
      allow(described_class).to receive(:find_signature_from_uuid).and_return(:result)

      expect(described_class.find_session_signature(submitter, cookies, [])).to eq(:result)
      expect(described_class).to have_received(:find_signature_from_uuid).with(submitter, 'uuid-1', anything)
    end

    it 'returns nil when cookie has no entry for submitter email' do
      submitter = double('submitter', email: 'a@example.com')
      cookies = double('cookies', encrypted: { signature_uuids: '{"b@example.com":"uuid-2"}' })

      expect(described_class.find_session_signature(submitter, cookies, [])).to be_nil
    end

    it 'returns nil when cookie is blank' do
      submitter = double('submitter', email: 'a@example.com')
      cookies = double('cookies', encrypted: { signature_uuids: '{}' })

      expect(described_class.find_session_signature(submitter, cookies, [])).to be_nil
    end
  end

  describe '.find_signature_from_uuid more cases' do
    it 'returns nil when attachment is not found' do
      submitter = double('submitter', email: 'x@example.com')
      allow(ActiveStorage::Attachment).to receive(:find_by).with(uuid: 'gone').and_return(nil)

      expect(described_class.find_signature_from_uuid(submitter, 'gone', [])).to be_nil
    end

    it 'returns existing attachment when blob match is found' do
      record = double('record', email: 's@example.com')
      sig = double('sig', record: record, blob_id: 42)
      submitter = double('submitter', email: 's@example.com', id: 5)
      existing = double('existing', blob_id: 42, record_id: 5)
      allow(ActiveStorage::Attachment).to receive(:find_by).with(uuid: 'u').and_return(sig)

      expect(described_class.find_signature_from_uuid(submitter, 'u', [existing])).to eq(existing)
    end

    it 'creates new attachment record when no match in existing attachments' do
      record = double('record', email: 's@example.com')
      sig = double('sig', record: record, blob_id: 42)
      attachments_assoc = double('assoc')
      submitter = double('submitter', email: 's@example.com', id: 5,
                                       attachments_attachments: attachments_assoc)
      allow(attachments_assoc).to receive(:create_or_find_by!).with(blob_id: 42).and_return(:new_attachment)
      allow(ActiveStorage::Attachment).to receive(:find_by).with(uuid: 'u').and_return(sig)

      expect(described_class.find_signature_from_uuid(submitter, 'u', [])).to eq(:new_attachment)
    end
  end
end
