# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::SubmitValues do
  describe '.normalized_values' do
    it 'casts boolean values when cast_boolean is true' do
      params = ActionController::Parameters.new(
        values: { 'a' => 'true', 'b' => 'false' },
        cast_boolean: 'true'
      )

      expect(described_class.normalized_values(params)).to eq({ 'a' => true, 'b' => false })
    end

    it 'casts number values when cast_number is true' do
      params = ActionController::Parameters.new(
        values: { 'int' => '12', 'float' => '12.5', 'blank' => '' },
        cast_number: 'true'
      )

      expect(described_class.normalized_values(params)).to eq({ 'int' => 12, 'float' => 12.5, 'blank' => nil })
    end

    it 'normalizes phone values when normalize_phone is true' do
      params = ActionController::Parameters.new(
        values: { 'phone' => '+33 (0)6-12 34' },
        normalize_phone: 'true'
      )

      expect(described_class.normalized_values(params)).to eq({ 'phone' => '+33061234' })
    end
  end

  describe '.required_editable_field?' do
    it 'returns false for non-editable types' do
      expect(described_class.required_editable_field?({ 'type' => 'heading', 'required' => true })).to be(false)
    end

    it 'returns true for required editable field' do
      expect(described_class.required_editable_field?({ 'type' => 'text', 'required' => true, 'readonly' => nil })).to be(true)
    end
  end

  describe '.check_field_areas_attachments' do
    it 'returns true when field has no areas' do
      expect(described_class.check_field_areas_attachments({ 'areas' => [] }, {})).to be(true)
    end

    it 'returns true when at least one area attachment exists' do
      field = { 'areas' => [{ 'attachment_uuid' => 'a1' }, { 'attachment_uuid' => 'a2' }] }
      attachments_index = { 'a2' => { 'ok' => true } }

      expect(described_class.check_field_areas_attachments(field, attachments_index)).to be(true)
    end
  end

  describe '.field_conditions_other_submitter?' do
    it 'detects condition referencing another submitter field' do
      submitter = double('submitter', uuid: 's1')
      field = { 'conditions' => [{ 'field_uuid' => 'f2' }] }
      fields_uuid_index = { 'f2' => { 'submitter_uuid' => 's2' } }

      expect(described_class.field_conditions_other_submitter?(submitter, field, fields_uuid_index)).to be(true)
    end
  end

  describe '.check_field_condition' do
    it 'handles empty and not_empty actions' do
      expect(described_class.check_field_condition({ 'action' => 'empty', 'field_uuid' => 'f' }, { 'f' => '' }, {})).to be(true)
      expect(described_class.check_field_condition({ 'action' => 'not_empty', 'field_uuid' => 'f' }, { 'f' => 'x' }, {})).to be(true)
    end

    it 'handles numeric comparisons' do
      field_index = { 'n' => { 'type' => 'number' } }
      expect(described_class.check_field_condition({ 'action' => 'equal', 'field_uuid' => 'n', 'value' => '10' }, { 'n' => '10' }, field_index)).to be(true)
      expect(described_class.check_field_condition({ 'action' => 'greater_than', 'field_uuid' => 'n', 'value' => '9' }, { 'n' => '10' }, field_index)).to be(true)
      expect(described_class.check_field_condition({ 'action' => 'less_than', 'field_uuid' => 'n', 'value' => '11' }, { 'n' => '10' }, field_index)).to be(true)
    end

    it 'handles option-based equal and not_equal actions' do
      field = {
        'options' => [{ 'uuid' => 'o1', 'value' => 'Approved' }]
      }
      index = { 'f' => field }

      expect(described_class.check_field_condition({ 'action' => 'equal', 'field_uuid' => 'f', 'value' => 'o1' },
                                                   { 'f' => ['Approved'] }, index)).to be(true)
      expect(described_class.check_field_condition({ 'action' => 'not_equal', 'field_uuid' => 'f', 'value' => 'o1' },
                                                   { 'f' => ['Rejected'] }, index)).to be(true)
    end
  end

  describe '.replace_default_variables' do
    let(:submission) { double('submission', account: double('account', timezone: 'UTC', locale: :en)) }

    it 'returns non-string values unchanged' do
      expect(described_class.replace_default_variables(true, {}, submission)).to be(true)
      expect(described_class.replace_default_variables(42, {}, submission)).to eq(42)
    end

    it 'replaces core placeholders' do
      attrs = { 'submission_id' => 123, 'email' => 'a@example.com', 'role' => 'Signer' }
      value = 'ID={{id}} ROLE={{role}} EMAIL={{email}}'

      result = described_class.replace_default_variables(value, attrs, submission, with_time: false)

      expect(result).to include('123', 'Signer', 'a@example.com')
    end
  end

  describe '.merge_default_values' do
    it 'adds stamp attachment uuid and replaces default placeholders' do
      field_stamp = { 'uuid' => 'st1', 'type' => 'stamp', 'submitter_uuid' => 's1', 'preferences' => {} }
      field_text = { 'uuid' => 't1', 'type' => 'text', 'submitter_uuid' => 's1', 'default_value' => '{{name}}' }
      submission = double('submission', template_fields: [field_stamp, field_text])
      submitter = double('submitter', uuid: 's1', submission: submission, values: {}, name: 'Jane')

      allow(Submitters::CreateStampAttachment).to receive(:build_attachment).and_return(double('att', uuid: 'att-1'))
      allow(described_class).to receive(:template_default_value_for_submitter).with('{{name}}', submitter, with_time: true)
                                                                     .and_return('Jane')

      values = described_class.merge_default_values(submitter)

      expect(values).to include('st1' => 'att-1', 't1' => 'Jane')
    end

    it 'raises when required verification field is not verified' do
      field_verif = { 'uuid' => 'v1', 'type' => 'verification', 'required' => true, 'submitter_uuid' => 's1' }
      submission_events = double('events')
      submission = double('submission', template_fields: [field_verif])
      submitter = double('submitter', uuid: 's1', submission: submission, values: {}, submission_events: submission_events)
      allow(submission_events).to receive(:exists?).with(event_type: :complete_verification).and_return(false)

      expect do
        described_class.merge_default_values(submitter, with_verification: true)
      end.to raise_error(Submitters::SubmitValues::ValidationError, /ID Not Verified/)
    end
  end

  describe '.check_field_conditions' do
    it 'evaluates OR operation groups correctly' do
      field = {
        'conditions' => [
          { 'action' => 'not_empty', 'field_uuid' => 'f1' },
          { 'action' => 'not_empty', 'field_uuid' => 'f2', 'operation' => 'or' }
        ]
      }

      values = { 'f1' => '', 'f2' => 'x' }

      expect(described_class.check_field_conditions(values, field, {})).to be(true)
    end
  end

  describe '.maybe_remove_condition_values' do
    it 'removes value when attachment condition no longer matches and updates required set' do
      field = {
        'uuid' => 'f1',
        'type' => 'text',
        'required' => true,
        'submitter_uuid' => 's1',
        'areas' => [{ 'attachment_uuid' => 'a1' }]
      }
      submission = double('submission',
                          template_submitters: [{ 'uuid' => 's1' }],
                          template_fields: [field],
                          template_schema: [{ 'conditions' => [{ 'a' => 1 }] }],
                          fields_uuid_index: {})
      submitter = double('submitter', uuid: 's1', submission: submission, values: { 'f1' => 'value' })
      allow(submitter).to receive(:values).and_return({ 'f1' => 'value' })
      allow(submitter).to receive(:values=) { |v| allow(submitter).to receive(:values).and_return(v) }

      allow(described_class).to receive(:submission_has_document_conditions?).and_return(true)
      allow(Submissions).to receive(:filtered_conditions_schema).and_return([])
      allow(described_class).to receive(:check_field_conditions).and_return(false)

      required = Set.new
      described_class.maybe_remove_condition_values(submitter, required_field_uuids_acc: required)

      expect(submitter.values['f1']).to be_nil
      expect(required).not_to include('f1')
    end
  end

  describe '.maybe_invite_via_field' do
    it 'creates invited submitter from email field and sets preserved order' do
      template_submitter = { 'uuid' => 'next-uuid', 'invite_via_field_uuid' => 'field-email' }
      field = { 'uuid' => 'field-email', 'submitter_uuid' => 's1' }
      relation = double('submitters_relation')
      submission = double('submission',
                          template_submitters: [template_submitter],
                          template_fields: [field],
                          submitters: relation)
      submitter = double('submitter', uuid: 's1', submission: submission, values: { 'field-email' => 'new@example.com' },
                                      account_id: 10)
      request = double('request')

      allow(relation).to receive(:exists?).with(uuid: 'next-uuid').and_return(false)
      allow(Submissions).to receive(:normalize_email).with('new@example.com').and_return('new@example.com')
      allow(relation).to receive(:create!)
      allow(SubmissionEvents).to receive(:create_with_tracking_data)
      allow(submission).to receive(:update!)

      described_class.maybe_invite_via_field(submitter, request)

      expect(relation).to have_received(:create!).with(uuid: 'next-uuid', email: 'new@example.com', phone: nil, account_id: 10)
      expect(submission).to have_received(:update!).with(submitters_order: :preserved)
    end
  end

  describe '.validate_value!' do
    it 'raises when field is readonly' do
      submitter = double('submitter', id: 7)

      expect do
        described_class.validate_value!('x', { 'readonly' => true, 'uuid' => 'f1' }, {}, submitter, nil)
      end.to raise_error(Submitters::SubmitValues::ValidationError, /Read-only field/)
    end
  end
end
