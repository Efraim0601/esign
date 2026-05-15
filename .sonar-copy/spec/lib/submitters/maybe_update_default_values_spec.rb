# frozen_string_literal: true

RSpec.describe Submitters::MaybeUpdateDefaultValues do
  describe '.get_default_value_for_field' do
    it 'uses user full name for known full-name fields' do
      field = { 'name' => 'Full Name', 'type' => 'text' }
      user = double('user', full_name: 'Jane Doe')
      submitter = double('submitter', name: 'Fallback')

      expect(described_class.get_default_value_for_field(field, user, submitter)).to eq('Jane Doe')
    end

    it 'creates initials attachment and returns uuid' do
      field = { 'name' => 'Initials', 'type' => 'initials' }
      blob = double('blob', blob_id: 12)
      attachment = double('attachment', uuid: 'att-1')
      user = double('user')
      submitter = double('submitter')

      allow(UserConfigs).to receive(:load_initials).with(user).and_return(blob)
      allow(ActiveStorage::Attachment).to receive(:find_or_create_by!).and_return(attachment)

      expect(described_class.get_default_value_for_field(field, user, submitter)).to eq('att-1')
    end
  end

  describe '.call' do
    it 'fills missing submitter values and saves submitter' do
      values = {}
      fields = [{ 'uuid' => 'f1', 'name' => 'full name', 'submitter_uuid' => 's1', 'type' => 'text' }]
      template = double('template', fields: fields)
      submission = double('submission', template_fields: fields, template: template)
      account = double('account', users: double('users', find_by: nil))
      submitter = double('submitter',
                         email: 's@example.com',
                         uuid: 's1',
                         values: values,
                         submission: submission,
                         account: account,
                         name: 'Sub Name')
      user = double('user', email: 's@example.com', full_name: 'User Name')

      allow(submitter).to receive(:save!)

      described_class.call(submitter, user)

      expect(values['f1']).to eq('User Name')
      expect(submitter).to have_received(:save!)
    end
  end
end
