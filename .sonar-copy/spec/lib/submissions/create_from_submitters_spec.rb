# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::CreateFromSubmitters do
  describe '.submitter_message_preferences' do
    it 'returns empty when per-submitter email is disabled' do
      result = described_class.submitter_message_preferences('u1', {
                                                               request_email_per_submitter: '0',
                                                               is_custom_message: '1'
                                                             })

      expect(result).to eq({})
    end

    it 'returns subject and body when custom messaging is enabled' do
      params = {
        request_email_per_submitter: '1',
        is_custom_message: '1',
        'submitter_preferences' => {
          'u1' => { 'subject' => 'Bonjour', 'body' => 'Message' }
        }
      }

      result = described_class.submitter_message_preferences('u1', params)

      expect(result).to eq({ 'subject' => 'Bonjour', 'body' => 'Message' })
    end
  end

  describe '.find_submitter_uuid' do
    let(:submitters) do
      [
        { 'uuid' => 'a1', 'name' => 'Signer' },
        { 'uuid' => 'b2', 'name' => 'Manager' }
      ]
    end

    it 'prefers explicit uuid' do
      uuid = described_class.find_submitter_uuid(submitters, { uuid: 'z9', role: 'Signer' }, 0)

      expect(uuid).to eq('z9')
    end

    it 'falls back to role matching then index' do
      by_role = described_class.find_submitter_uuid(submitters, { role: 'manager' }, 0)
      by_index = described_class.find_submitter_uuid(submitters, { index: 0 }, 1)

      expect(by_role).to eq('b2')
      expect(by_index).to eq('a1')
    end
  end

  describe '.process_readonly_fields_param' do
    it 'marks matching fields as readonly using multiple name strategies' do
      fields = [
        { 'submitter_uuid' => 'u1', 'name' => 'Customer Name' },
        { 'submitter_uuid' => 'u1', 'name' => 'Email' },
        { 'submitter_uuid' => 'u2', 'name' => 'Customer Name' }
      ]

      described_class.process_readonly_fields_param(%w[customer_name email], fields, 'u1')

      expect(fields[0]['readonly']).to be(true)
      expect(fields[1]['readonly']).to be(true)
      expect(fields[2]['readonly']).to be_nil
    end
  end

  describe '.process_field_values_param' do
    it 'sets and clears default values for supported field types' do
      fields = [
        { 'uuid' => 't1', 'submitter_uuid' => 'u1', 'type' => 'text' },
        { 'uuid' => 's1', 'submitter_uuid' => 'u1', 'type' => 'signature', 'default_value' => 'keep' },
        { 'uuid' => 't2', 'submitter_uuid' => 'u1', 'type' => 'text', 'default_value' => 'old' }
      ]

      described_class.process_field_values_param({ 't1' => 'new', 't2' => '' }, fields, 'u1')

      expect(fields[0]['default_value']).to eq('new')
      expect(fields[1]['default_value']).to eq('keep')
      expect(fields[2]).not_to have_key('default_value')
    end
  end

  describe '.assign_field_attrs' do
    it 'assigns generic attrs and validation_pattern' do
      field = { 'type' => 'text' }
      attrs = {
        'title' => 'Titre',
        'description' => 'Desc',
        'readonly' => true,
        'required' => false,
        'preferences' => { 'a' => 1 },
        'validation' => { 'min' => 2 },
        'validation_pattern' => '^A',
        'invalid_message' => 'invalid'
      }

      described_class.assign_field_attrs(field, attrs)

      expect(field['title']).to eq('Titre')
      expect(field['description']).to eq('Desc')
      expect(field['readonly']).to be(true)
      expect(field['required']).to be(false)
      expect(field['preferences']).to eq({ 'a' => 1 })
      expect(field['validation']).to eq({ 'pattern' => '^A', 'message' => 'invalid' })
    end

    it 'normalizes default_value for non-signature fields only' do
      text_field = { 'type' => 'text' }
      sign_field = { 'type' => 'signature' }

      allow(Submitters::NormalizeValues).to receive(:normalize_value).with(text_field, ' A ').and_return('A')

      described_class.assign_field_attrs(text_field, { 'default_value' => ' A ' })
      described_class.assign_field_attrs(sign_field, { 'default_value' => 'X' })

      expect(text_field['default_value']).to eq('A')
      expect(sign_field).not_to have_key('default_value')
    end
  end

  describe '.build_merged_submitter' do
    it 'merges selected roles and rewrites linked uuid references' do
      submitters = [
        { 'uuid' => 'u1', 'name' => 'A', 'optional_invite_by_uuid' => 'u2' },
        { 'uuid' => 'u2', 'name' => 'B', 'invite_by_uuid' => 'u1' },
        { 'uuid' => 'u3', 'name' => 'C', 'linked_to_uuid' => 'u2' }
      ]

      merged, updated = described_class.build_merged_submitter(submitters, role_uuids: %w[u1 u2], name: 'A / B')

      expect(merged['name']).to eq('A / B')
      expect(updated.size).to eq(2)
      expect(updated.map { |s| s['uuid'] }).to include(merged['uuid'], 'u3')
      expect(updated.find { |s| s['uuid'] == 'u3' }['linked_to_uuid']).to eq(merged['uuid'])
    end
  end

  describe '.merge_submitters_and_fields' do
    it 'raises if one requested role does not exist' do
      submitters = [{ 'uuid' => 'u1', 'name' => 'Signer' }]
      fields = []

      expect do
        described_class.merge_submitters_and_fields({ roles: %w[Signer Missing], role: 'Merged' }, submitters, fields)
      end.to raise_error(Submissions::CreateFromSubmitters::BaseError, /doesn't exist/)
    end

    it 'merges duplicate-named fields areas under merged submitter' do
      submitters = [
        { 'uuid' => 'u1', 'name' => 'Signer' },
        { 'uuid' => 'u2', 'name' => 'Manager' }
      ]
      fields = [
        { 'submitter_uuid' => 'u1', 'name' => 'email', 'areas' => [{ 'uuid' => 'a1' }] },
        { 'submitter_uuid' => 'u2', 'name' => 'email', 'areas' => [{ 'uuid' => 'a2' }] }
      ]

      merged, _updated_submitters, updated_fields =
        described_class.merge_submitters_and_fields({ roles: %w[Signer Manager], role: 'Both' }, submitters, fields)

      merged_email = updated_fields.find { |f| f['name'] == 'email' }
      expect(merged['name']).to eq('Both')
      expect(merged_email['submitter_uuid']).to eq(merged['uuid'])
      expect(merged_email['areas'].size).to eq(2)
      expect(updated_fields.size).to eq(1)
    end
  end

  describe '.maybe_enqueue_expire_at' do
    it 'schedules expiration job only for expiring submissions' do
      with_expire = double('submission1', expire_at?: true, expire_at: Time.current, id: 1)
      without_expire = double('submission2', expire_at?: false, id: 2)

      allow(ProcessSubmissionExpiredJob).to receive(:perform_at)

      described_class.maybe_enqueue_expire_at([with_expire, without_expire])

      expect(ProcessSubmissionExpiredJob).to have_received(:perform_at).with(with_expire.expire_at, 'submission_id' => 1)
    end
  end

  describe '.assign_completed_attributes' do
    it 'resolves date and name placeholders in submitter values' do
      account = double('account', timezone: 'UTC')
      submission = double('submission', account: account)
      submitter = double('submitter', submission: submission, values: { 'd' => '{{date}}', 'n' => '{{name}}' })

      allow(submitter).to receive(:values=) do |value|
        allow(submitter).to receive(:values).and_return(value)
      end

      allow(Submitters::SubmitValues).to receive(:merge_default_values).and_return({ 'd' => '{{date}}', 'n' => '{{name}}' })
      allow(Submitters::SubmitValues).to receive(:maybe_remove_condition_values) { |s| s.values }
      allow(Submitters::SubmitValues).to receive(:build_formula_values).and_return({})
      allow(Submitters::SubmitValues).to receive(:submitter_display_name).and_return('Jane Doe')

      freeze_time do
        described_class.assign_completed_attributes(submitter)
      end

      expect(submitter.values['d']).to eq(Time.current.to_date.to_s)
      expect(submitter.values['n']).to eq('Jane Doe')
    end
  end
end
