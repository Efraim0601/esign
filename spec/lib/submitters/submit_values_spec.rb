# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::SubmitValues do
  describe '.call' do
    it 'creates start_form event and saves submission' do
      submission = double('submission', template_fields: [{}])
      events = double('events')
      submitter = double('submitter', submission: submission, submission_events: events, id: 10, completed_at?: false)
      request = double('request')
      params = ActionController::Parameters.new(values: {})

      allow(events).to receive(:exists?).with(event_type: 'start_form').and_return(false)
      allow(SubmissionEvents).to receive(:create_with_tracking_data)
      allow(WebhookUrls).to receive(:enqueue_events)
      allow(described_class).to receive(:update_submitter!).and_return(submitter)
      allow(submission).to receive(:save!)
      allow(ProcessSubmitterCompletionJob).to receive(:perform_async)

      described_class.call(submitter, params, request)

      expect(SubmissionEvents).to have_received(:create_with_tracking_data).with(submitter, 'start_form', request)
      expect(WebhookUrls).to have_received(:enqueue_events).with(submitter, 'form.started')
      expect(submission).to have_received(:save!)
      expect(ProcessSubmitterCompletionJob).not_to have_received(:perform_async)
    end
  end

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

    it 'removes blank entries in array values by default' do
      params = ActionController::Parameters.new(values: { 'arr' => ['A', '', nil, 'B'] })

      expect(described_class.normalized_values(params)).to eq({ 'arr' => %w[A B] })
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

    it 'keeps time placeholders untouched when with_time is false' do
      attrs = { 'submission_id' => 1 }
      result = described_class.replace_default_variables('{{time}}/{{date}}', attrs, submission, with_time: false)

      expect(result).to eq('{{time}}/{{date}}')
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

    it 'creates invited submitter from phone value' do
      template_submitter = { 'uuid' => 'next-uuid', 'invite_via_field_uuid' => 'field-phone' }
      field = { 'uuid' => 'field-phone', 'submitter_uuid' => 's1' }
      relation = double('submitters_relation')
      submission = double('submission',
                          template_submitters: [template_submitter],
                          template_fields: [field],
                          submitters: relation)
      submitter = double('submitter', uuid: 's1', submission: submission, values: { 'field-phone' => '+33 6 11 22 33' },
                                      account_id: 10)
      request = double('request')

      allow(relation).to receive(:exists?).with(uuid: 'next-uuid').and_return(false)
      allow(relation).to receive(:create!)
      allow(SubmissionEvents).to receive(:create_with_tracking_data)
      allow(submission).to receive(:update!)

      described_class.maybe_invite_via_field(submitter, request)

      expect(relation).to have_received(:create!).with(uuid: 'next-uuid', email: nil, phone: '+336112233', account_id: 10)
    end
  end

  describe '.validate_value!' do
    it 'raises when field is readonly' do
      submitter = double('submitter', id: 7)

      expect do
        described_class.validate_value!('x', { 'readonly' => true, 'uuid' => 'f1' }, {}, submitter, nil)
      end.to raise_error(Submitters::SubmitValues::ValidationError, /Read-only field/)
    end

    it 'returns true for editable fields' do
      submitter = double('submitter')

      expect(described_class.validate_value!('x', { 'readonly' => false, 'uuid' => 'f1' }, {}, submitter, nil)).to be(true)
    end
  end

  describe '.template_default_value_for_submitter' do
    it 'returns submitter display name for {{name}} shortcut' do
      submitter = double('submitter')
      allow(described_class).to receive(:submitter_display_name).with(submitter).and_return('Jane Signer')

      expect(described_class.template_default_value_for_submitter('{{name}}', submitter)).to eq('Jane Signer')
    end
  end

  describe '.normalize_formula' do
    it 'raises validation error when recursion depth is too high' do
      expect do
        described_class.normalize_formula('{{f1}}', double('submission'), depth: 11, submission_values: {})
      end.to raise_error(Submitters::SubmitValues::ValidationError, /infinite loop/)
    end

    it 'replaces nested formula references with parenthesized sub-formula' do
      fields_uuid_index = {
        'f1' => { 'uuid' => 'f1', 'preferences' => { 'formula' => '2 * 3' } }
      }
      submission = double('submission', fields_uuid_index: fields_uuid_index)
      allow(described_class).to receive(:check_field_conditions).and_return(true)

      result = described_class.normalize_formula('{{f1}}', submission, submission_values: {})

      expect(result).to eq('(2 * 3)')
    end

    it 'replaces with zero when nested formula conditions fail' do
      fields_uuid_index = {
        'f1' => { 'uuid' => 'f1', 'preferences' => { 'formula' => '2 * 3' } }
      }
      submission = double('submission', fields_uuid_index: fields_uuid_index)
      allow(described_class).to receive(:check_field_conditions).and_return(false)

      result = described_class.normalize_formula('{{f1}}', submission, submission_values: {})

      expect(result).to eq('0')
    end

    it 'leaves non-formula placeholders untouched' do
      submission = double('submission', fields_uuid_index: {})

      result = described_class.normalize_formula('{{not_a_formula}}', submission, submission_values: {})

      expect(result).to eq('{{not_a_formula}}')
    end
  end

  describe '.calculate_formula_value' do
    it 'returns 0 (placeholder implementation)' do
      expect(described_class.calculate_formula_value('1 + 1', {})).to eq(0)
    end
  end

  describe '.submitter_display_name' do
    it 'returns blank string when submitter is blank' do
      expect(described_class.submitter_display_name(nil)).to eq('')
    end

    it 'falls back to email when name is missing' do
      submitter = double('submitter', name: nil, email: 'a@example.com', phone: nil, account: double(users: double(find_by: nil)))

      expect(described_class.submitter_display_name(submitter)).to eq('a@example.com')
    end

    it 'falls back to phone when name and email are missing' do
      submitter = double('submitter', name: nil, email: nil, phone: '+33700000000', account: double(users: double(find_by: nil)))

      expect(described_class.submitter_display_name(submitter)).to eq('+33700000000')
    end

    it 'prefers matching account user full name when available' do
      account = double('account', users: double('users'))
      submitter = double('submitter', name: nil, email: 'a@example.com', phone: nil, account: account)
      allow(account.users).to receive(:find_by).with(email: 'a@example.com').and_return(double(full_name: 'Alice Account'))

      expect(described_class.submitter_display_name(submitter)).to eq('Alice Account')
    end
  end

  describe '.lookup_user_full_name' do
    it 'returns nil when submitter email is blank' do
      submitter = double('submitter', email: nil)

      expect(described_class.lookup_user_full_name(submitter)).to be_nil
    end
  end

  describe '.template_default_value_for_submitter' do
    it 'returns nil for blank value' do
      expect(described_class.template_default_value_for_submitter('', double('submitter'))).to be_nil
    end

    it 'returns nil for blank submitter' do
      expect(described_class.template_default_value_for_submitter('hi', nil)).to be_nil
    end

    it 'forwards to replace_default_variables for non-shortcut values' do
      submission = double('submission',
                          template_submitters: [{ 'uuid' => 's1', 'name' => 'Signer' }],
                          account: double('account', timezone: 'UTC', locale: :en))
      submitter = double('submitter', uuid: 's1', submission: submission,
                                       attributes: { 'email' => 'a@b.com' })

      result = described_class.template_default_value_for_submitter('Hello {{role}}', submitter, with_time: false)

      expect(result).to eq('Hello Signer')
    end
  end

  describe '.required_editable_field?' do
    it 'returns false for readonly fields' do
      expect(described_class.required_editable_field?({
                                                        'type' => 'text',
                                                        'required' => true,
                                                        'readonly' => true
                                                      })).to be(false)
    end

    it 'returns false when not required' do
      expect(described_class.required_editable_field?({
                                                        'type' => 'text',
                                                        'required' => false,
                                                        'readonly' => false
                                                      })).to be(false)
    end

    it 'returns false for stamp type' do
      expect(described_class.required_editable_field?({
                                                        'type' => 'stamp',
                                                        'required' => true
                                                      })).to be(false)
    end
  end

  describe '.replace_default_variables' do
    let(:submission) { double('submission', account: double('account', timezone: 'UTC', locale: :en)) }

    it 'replaces {{time}} and {{date}} when with_time is true' do
      travel_to(Time.utc(2026, 5, 13, 12, 30)) do
        result = described_class.replace_default_variables('TIME={{time}} DATE={{date}}',
                                                           { 'submission_id' => 1 }, submission, with_time: true)

        expect(result).to include('TIME=')
        expect(result).to include('DATE=')
      end
    end
  end

  describe '.submission_has_document_conditions?' do
    it 'returns true when template_schema has conditions' do
      submission = double('submission',
                          template_schema: [{ 'conditions' => [{ 'a' => 1 }] }],
                          template: nil)

      expect(described_class.submission_has_document_conditions?(submission)).to be(true)
    end

    it 'falls back to template.schema when template_schema is nil' do
      submission = double('submission', template_schema: nil,
                                        template: double('template',
                                                         schema: [{ 'conditions' => [{ 'a' => 1 }] }]))

      expect(described_class.submission_has_document_conditions?(submission)).to be(true)
    end

    it 'returns false when no conditions present' do
      submission = double('submission',
                          template_schema: [{}, { 'conditions' => [] }],
                          template: nil)

      expect(described_class.submission_has_document_conditions?(submission)).to be(false)
    end
  end

  describe '.check_field_areas_attachments coverage' do
    it 'returns false when none of areas have matching attachment in index' do
      field = { 'areas' => [{ 'attachment_uuid' => 'a1' }, { 'attachment_uuid' => 'a2' }] }

      expect(described_class.check_field_areas_attachments(field, { 'a3' => {} })).to be(false)
    end
  end

  describe '.field_conditions_other_submitter?' do
    it 'returns false when all conditions reference fields owned by current submitter' do
      submitter = double('submitter', uuid: 's1')
      field = { 'conditions' => [{ 'field_uuid' => 'f1' }] }
      fields_uuid_index = { 'f1' => { 'submitter_uuid' => 's1' } }

      expect(described_class.field_conditions_other_submitter?(submitter, field, fields_uuid_index)).to be(false)
    end

    it 'returns false when field has no conditions' do
      submitter = double('submitter', uuid: 's1')

      expect(described_class.field_conditions_other_submitter?(submitter, {}, {})).to be_falsey
    end
  end

  describe '.normalized_values defaults' do
    it 'returns values as is when no casting flags are set' do
      params = ActionController::Parameters.new(values: { 'x' => 'hello' })

      expect(described_class.normalized_values(params)).to eq({ 'x' => 'hello' })
    end

    it 'returns empty hash when no values key present' do
      params = ActionController::Parameters.new
      expect(described_class.normalized_values(params)).to eq({})
    end
  end

  describe '.check_field_condition more actions' do
    it 'handles contains and not_contains' do
      expect(described_class.check_field_condition({ 'action' => 'contains', 'field_uuid' => 'f', 'value' => 'foo' },
                                                   { 'f' => 'foobar' }, {})).to be(true)
      expect(described_class.check_field_condition({ 'action' => 'not_contains', 'field_uuid' => 'f', 'value' => 'foo' },
                                                   { 'f' => 'barbaz' }, {})).to be(true)
    end

    it 'returns true when value matches array (multi-select equal)' do
      field = { 'options' => [{ 'uuid' => 'o1', 'value' => 'A' }] }
      expect(described_class.check_field_condition({ 'action' => 'equal', 'field_uuid' => 'f', 'value' => 'o1' },
                                                   { 'f' => ['A', 'B'] }, { 'f' => field })).to be(true)
    end

    it 'handles numeric equality with floats' do
      field_index = { 'n' => { 'type' => 'number' } }
      expect(described_class.check_field_condition({ 'action' => 'equal', 'field_uuid' => 'n', 'value' => '10.5' },
                                                   { 'n' => '10.5' }, field_index)).to be(true)
    end

    it 'returns false on greater_than when value is blank' do
      expect(described_class.check_field_condition({ 'action' => 'greater_than', 'field_uuid' => 'n', 'value' => '9' },
                                                   { 'n' => '' },
                                                   { 'n' => { 'type' => 'number' } })).to be(false)
    end

    it 'returns false on less_than when no field is found in index' do
      expect(described_class.check_field_condition({ 'action' => 'less_than', 'field_uuid' => 'unknown', 'value' => '10' },
                                                   { 'unknown' => '5' }, {})).to be(false)
    end

    it 'uses default option label when option value is blank' do
      field = { 'options' => [{ 'uuid' => 'o1', 'value' => '' }] }
      allow(I18n).to receive(:t).with('option').and_return('Option')
      expect(described_class.check_field_condition({ 'action' => 'equal', 'field_uuid' => 'f', 'value' => 'o1' },
                                                   { 'f' => 'Option 1' }, { 'f' => field })).to be(true)
    end

    it 'returns false for not_equal when option does not exist' do
      field = { 'options' => [{ 'uuid' => 'o1', 'value' => 'A' }] }
      expect(described_class.check_field_condition({ 'action' => 'not_equal', 'field_uuid' => 'f', 'value' => 'missing' },
                                                   { 'f' => 'A' }, { 'f' => field })).to be(false)
    end

    it 'returns true when not_equal field is missing from index' do
      expect(described_class.check_field_condition({ 'action' => 'not_equal', 'field_uuid' => 'f', 'value' => 'A' },
                                                   { 'f' => 'X' }, {})).to be(true)
    end

    it 'returns true for unknown action' do
      expect(described_class.check_field_condition({ 'action' => 'unknown_action', 'field_uuid' => 'f' },
                                                   { 'f' => 'X' }, {})).to be(true)
    end
  end

  describe '.maybe_set_signature_reason!' do
    it 'returns nil when params[:with_reason] is blank' do
      submitter = double('submitter')

      expect(described_class.maybe_set_signature_reason!({}, submitter, {})).to be_nil
    end

    it 'sets reason field reference in signature preferences and adds reason field if missing' do
      signature_field = { 'uuid' => 'sig-1', 'type' => 'signature', 'preferences' => nil }
      template_fields = [signature_field]
      submission = double('submission', template_fields: template_fields, save!: true)
      submitter = double('submitter', uuid: 's1', submission: submission)
      values = { 'sig-1' => 'sig-data', 'reason-1' => 'because' }
      allow(I18n).to receive(:t).with(:reason).and_return('Reason')

      result = described_class.maybe_set_signature_reason!(values, submitter, { with_reason: 'reason-1' })

      expect(signature_field['preferences']['reason_field_uuid']).to eq('reason-1')
      expect(template_fields.size).to eq(2)
      expect(template_fields.last['uuid']).to eq('reason-1')
      expect(result['uuid']).to eq('reason-1')
    end

    it 'leaves existing reason field in place' do
      reason_field = { 'uuid' => 'reason-1', 'type' => 'text' }
      signature_field = { 'uuid' => 'sig-1', 'type' => 'signature', 'preferences' => {} }
      template_fields = [signature_field, reason_field]
      submission = double('submission', template_fields: template_fields, save!: true)
      submitter = double('submitter', uuid: 's1', submission: submission)
      values = { 'sig-1' => 'sig-data', 'reason-1' => 'because' }

      result = described_class.maybe_set_signature_reason!(values, submitter, { with_reason: 'reason-1' })

      expect(result).to eq(reason_field)
      expect(template_fields.size).to eq(2)
    end
  end

  describe '.assign_completed_attributes' do
    it 'sets ip, ua, timezone, and resolves {{date}} placeholders' do
      template_fields = []
      submission = double('submission', template_fields: template_fields, template_submitters: [{ 'uuid' => 's1' }],
                                        template_schema: [], fields_uuid_index: {})
      submitter = double('submitter', uuid: 's1', submission: submission,
                                       account: double('account', timezone: 'UTC'))
      values_store = { 'f1' => '{{date}}' }
      allow(submitter).to receive(:values).and_return(values_store)
      allow(submitter).to receive(:values=) { |v| values_store.replace(v) }
      allow(submitter).to receive(:completed_at=)
      allow(submitter).to receive(:ip=)
      allow(submitter).to receive(:ua=)
      allow(submitter).to receive(:timezone=)
      allow(described_class).to receive(:submitter_display_name).and_return('Display')

      request = double('request', remote_ip: '1.2.3.4', user_agent: 'TestUA',
                                  params: { timezone: 'Europe/Paris' })

      described_class.assign_completed_attributes(submitter, request)

      expect(submitter).to have_received(:ip=).with('1.2.3.4')
      expect(submitter).to have_received(:ua=).with('TestUA')
      expect(submitter).to have_received(:timezone=).with('Europe/Paris')
      expect(values_store['f1']).to match(/\A\d{4}-\d{2}-\d{2}\z/)
    end

    it 'raises RequiredFieldError when a required field has no value' do
      required_field = { 'uuid' => 'r1', 'type' => 'text', 'submitter_uuid' => 's1',
                         'required' => true, 'readonly' => false }
      submission = double('submission', template_fields: [required_field],
                                        template_submitters: [{ 'uuid' => 's1' }],
                                        template_schema: [], fields_uuid_index: {})
      submitter = double('submitter', uuid: 's1', submission: submission, id: 5,
                                       account: double('account', timezone: 'UTC'))
      values_store = {}
      allow(submitter).to receive(:values).and_return(values_store)
      allow(submitter).to receive(:values=) { |v| values_store.replace(v) }
      allow(submitter).to receive(:completed_at=)
      allow(submitter).to receive(:ip=)
      allow(submitter).to receive(:ua=)
      allow(submitter).to receive(:timezone=)

      request = double('request', remote_ip: '1.2.3.4', user_agent: 'UA',
                                  params: { timezone: nil })

      expect do
        described_class.assign_completed_attributes(submitter, request)
      end.to raise_error(Submitters::SubmitValues::RequiredFieldError, 'r1')
    end

    it 'skips raising when validate_required is false' do
      required_field = { 'uuid' => 'r1', 'type' => 'text', 'submitter_uuid' => 's1',
                         'required' => true, 'readonly' => false }
      submission = double('submission', template_fields: [required_field],
                                        template_submitters: [{ 'uuid' => 's1' }],
                                        template_schema: [], fields_uuid_index: {})
      submitter = double('submitter', uuid: 's1', submission: submission, id: 5,
                                       account: double('account', timezone: 'UTC'))
      values_store = {}
      allow(submitter).to receive(:values).and_return(values_store)
      allow(submitter).to receive(:values=) { |v| values_store.replace(v) }
      allow(submitter).to receive(:completed_at=)
      allow(submitter).to receive(:ip=)
      allow(submitter).to receive(:ua=)
      allow(submitter).to receive(:timezone=)

      request = double('request', remote_ip: '1.2.3.4', user_agent: 'UA',
                                  params: { timezone: nil })

      expect do
        described_class.assign_completed_attributes(submitter, request, validate_required: false)
      end.not_to raise_error
    end
  end

  describe '.validate_value! readonly' do
    it 'raises ValidationError on readonly fields' do
      submitter = double('submitter', id: 9)

      expect do
        described_class.validate_value!('x', { 'readonly' => true, 'uuid' => 'f1' }, {}, submitter, nil)
      end.to raise_error(Submitters::SubmitValues::ValidationError, /Read-only field/)
    end
  end

  describe '.merge_submitters_values' do
    it 'merges all submitters values then overrides with current submitter values' do
      s1 = double('s1', values: { 'a' => 1, 'b' => 2 })
      s2 = double('s2', values: { 'b' => 99, 'c' => 3 })
      submission = double('submission', submitters: [s1, s2])
      submitter = double('submitter', submission: submission, values: { 'b' => 100 })

      result = described_class.merge_submitters_values(submitter)

      expect(result).to eq({ 'a' => 1, 'b' => 100, 'c' => 3 })
    end
  end

  describe '.update_submitter!' do
    it 'merges values, sets opened_at, runs validations and saves transactionally' do
      submission = double('submission', template_fields: [], save!: true)
      values_store = { 'existing' => 'val' }
      submitter = double('submitter', submission: submission,
                                       values: values_store,
                                       opened_at: nil, completed_at?: false,
                                       id: 1)
      allow(submitter).to receive(:opened_at=)
      allow(submitter).to receive(:save!)

      params = ActionController::Parameters.new(values: { 'new' => 'val2' })
      request = double('request')

      allow(ApplicationRecord).to receive(:transaction).and_yield
      allow(described_class).to receive(:validate_values!)
      allow(described_class).to receive(:maybe_set_signature_reason!).and_return(nil)

      described_class.update_submitter!(submitter, params, request)

      expect(submitter).to have_received(:opened_at=)
      expect(submitter).to have_received(:save!)
      expect(values_store).to include('new' => 'val2')
    end

    it 'enqueues search reindex when submitter is completed' do
      submission = double('submission', template_fields: [], save!: true)
      submitter = double('submitter', submission: submission, values: {},
                                       opened_at: Time.current, completed_at?: true, id: 1)
      allow(submitter).to receive(:save!)
      allow(SearchEntries).to receive(:enqueue_reindex)

      params = ActionController::Parameters.new
      request = double('request')

      allow(ApplicationRecord).to receive(:transaction).and_yield
      allow(described_class).to receive(:validate_values!)

      described_class.update_submitter!(submitter, params, request)

      expect(SearchEntries).to have_received(:enqueue_reindex).with(submitter)
    end

    it 'touches attachments when touch_attachment_uuid is provided' do
      submission = double('submission', template_fields: [], save!: true)
      submitter = double('submitter', submission: submission, values: {},
                                       opened_at: Time.current, completed_at?: false, id: 1)
      allow(submitter).to receive(:save!)
      relation = double('relation')
      allow(ActiveStorage::Attachment).to receive(:where)
        .with(uuid: 'att-1', record: submitter).and_return(relation)
      allow(relation).to receive(:touch_all)

      params = ActionController::Parameters.new(values: {}, touch_attachment_uuid: 'att-1')
      request = double('request')

      allow(ApplicationRecord).to receive(:transaction).and_yield
      allow(described_class).to receive(:validate_values!)

      described_class.update_submitter!(submitter, params, request)

      expect(relation).to have_received(:touch_all).with(:created_at)
    end
  end

  describe '.call completion path' do
    it 'enqueues ProcessSubmitterCompletionJob when submitter becomes completed' do
      submission = double('submission', template_fields: [{}])
      events = double('events')
      submitter = double('submitter', submission: submission, submission_events: events, id: 42, completed_at?: true)
      request = double('request')
      params = ActionController::Parameters.new(values: {})

      allow(events).to receive(:exists?).with(event_type: 'start_form').and_return(true)
      allow(described_class).to receive(:update_submitter!).and_return(submitter)
      allow(submission).to receive(:save!)
      allow(ProcessSubmitterCompletionJob).to receive(:perform_async)

      described_class.call(submitter, params, request)

      expect(ProcessSubmitterCompletionJob).to have_received(:perform_async).with('submitter_id' => 42)
    end

    it 'updates template_fields when submission has no fields yet' do
      submission = double('submission', template_fields: [])
      events = double('events')
      submitter = double('submitter', submission: submission, submission_events: events, id: 5, completed_at?: false)
      params = ActionController::Parameters.new(values: {})

      allow(Submissions).to receive(:update_template_fields!)
      allow(events).to receive(:exists?).and_return(true)
      allow(described_class).to receive(:update_submitter!).and_return(submitter)
      allow(submission).to receive(:save!)

      described_class.call(submitter, params, double('request'))

      expect(Submissions).to have_received(:update_template_fields!).with(submission)
    end
  end
end
