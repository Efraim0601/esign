# frozen_string_literal: true

RSpec.describe ActionMailerEventsObserver do
  describe '.delivered_email' do
    it 'creates send events for to/cc/bcc recipients' do
      header = double('header', value: 'msg-uuid')
      delivery_method = double('delivery_method', class: double('klass', name: 'DeliveryMethod'))
      mail = double('mail',
                    from: ['from@example.test'],
                    to: ['to@example.test'],
                    cc: ['cc@example.test'],
                    bcc: ['bcc@example.test'],
                    delivery_method: delivery_method)
      allow(mail).to receive(:[]).with('X-Message-Uuid').and_return(header)
      allow(mail).to receive(:instance_variable_get).with(:@message_metadata).and_return(
        { 'tag' => 'submission.created', 'record_id' => 8, 'record_type' => 'Submission' }
      )

      allow(EmailEvent).to receive(:create!)

      described_class.delivered_email(mail)

      expect(EmailEvent).to have_received(:create!).exactly(3).times
      expect(EmailEvent).to have_received(:create!).with(hash_including(
        tag: 'submission.created',
        message_id: 'msg-uuid',
        emailable_id: 8,
        emailable_type: 'Submission',
        event_type: :send
      )).at_least(:once)
    end

    it 'returns without creating events when metadata is blank' do
      mail = double('mail')
      allow(mail).to receive(:instance_variable_get).with(:@message_metadata).and_return(nil)
      allow(EmailEvent).to receive(:create!)

      expect(described_class.delivered_email(mail)).to be_nil
      expect(EmailEvent).not_to have_received(:create!)
    end
  end

  describe '.fetch_message_id' do
    it 'falls back to random uuid when header is absent' do
      mail = double('mail')
      allow(mail).to receive(:[]).with('X-Message-Uuid').and_return(nil)
      allow(SecureRandom).to receive(:uuid).and_return('generated-uuid')

      expect(described_class.fetch_message_id(mail)).to eq('generated-uuid')
    end
  end

  describe '.all_emails' do
    it 'returns combined to/cc/bcc arrays' do
      mail = double('mail', to: ['to@example.test'], cc: ['cc@example.test'], bcc: ['bcc@example.test'])

      expect(described_class.all_emails(mail)).to eq(['to@example.test', 'cc@example.test', 'bcc@example.test'])
    end
  end
end
