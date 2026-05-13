# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions do
  describe '.parse_emails' do
    it 'returns array input unchanged' do
      expect(described_class.parse_emails(%w[a@example.com b@example.com], nil)).to eq(%w[a@example.com b@example.com])
    end

    it 'extracts emails from free text' do
      text = 'a@example.com; b@example.com / c@example.com'
      result = described_class.parse_emails(text, nil)

      expect(result).to include('a@example.com', 'b@example.com', 'c@example.com')
    end
  end

  describe '.normalize_email' do
    it 'normalizes gmail typos ending with @gmail' do
      expect(described_class.normalize_email('User@GMAIL')).to eq('user@gmail.com')
    end

    it 'downcases addresses containing commas' do
      expect(described_class.normalize_email('A@EXAMPLE.COM,B@EXAMPLE.COM')).to eq('a@example.com,b@example.com')
    end

    it 'returns nil for blank or numeric values' do
      expect(described_class.normalize_email(nil)).to be_nil
      expect(described_class.normalize_email(123)).to be_nil
    end
  end

  describe '.check_item_conditions' do
    it 'returns true when no conditions are provided' do
      expect(described_class.check_item_conditions({ 'conditions' => [] }, {}, {})).to be(true)
    end

    it 'supports include_submitter_uuid shortcut and mixed OR logic' do
      item = {
        'conditions' => [
          { 'field_uuid' => 'f1', 'action' => 'not_empty' },
          { 'field_uuid' => 'f2', 'action' => 'not_empty', 'operation' => 'or' }
        ]
      }
      values = { 'f1' => '', 'f2' => '' }
      fields_index = {
        'f1' => { 'submitter_uuid' => 's1' },
        'f2' => { 'submitter_uuid' => 's2' }
      }

      # f1 is forced true via include_submitter_uuid, then OR with f2(false) => true
      expect(
        described_class.check_item_conditions(item, values, fields_index, include_submitter_uuid: 's1')
      ).to be(true)
    end
  end

  describe '.filtered_conditions_schema' do
    it 'filters schema items based on conditions results' do
      submission = double('submission')
      allow(submission).to receive(:template_schema).and_return([
                                                                  { 'attachment_uuid' => 'a1' },
                                                                  { 'attachment_uuid' => 'a2',
                                                                    'conditions' => [{ 'field_uuid' => 'f1', 'action' => 'not_empty' }] }
                                                                ])
      allow(submission).to receive(:template).and_return(double('template', schema: []))
      allow(submission).to receive(:fields_uuid_index).and_return({ 'f1' => { 'submitter_uuid' => 's2' } })
      allow(submission).to receive(:submitters).and_return([double('sub', values: { 'f1' => '' })])

      result = described_class.filtered_conditions_schema(submission)

      expect(result.map { |i| i['attachment_uuid'] }).to eq(['a1'])
    end
  end

  describe '.search' do
    it 'delegates to plain_search when fulltext is disabled' do
      allow(Docuseal).to receive(:fulltext_search?).and_return(false)
      allow(described_class).to receive(:plain_search).and_return(:result)

      expect(described_class.search(double('user'), :scope, 'abc')).to eq(:result)
    end
  end

  describe '.send_signature_requests' do
    it 'sends to first ordered group when template submitters define order' do
      s1 = double('s1', uuid: 'u1', completed_at?: false)
      s2 = double('s2', uuid: 'u2', completed_at?: false)
      submission = double(
        'submission',
        template_submitters: [{ 'uuid' => 'u1', 'order' => 1 }, { 'uuid' => 'u2', 'order' => 2 }],
        submitters: [s1, s2],
        submitters_order_preserved?: false
      )
      allow(Submitters).to receive(:send_signature_requests)

      described_class.send_signature_requests([submission], delay: 5)

      expect(Submitters).to have_received(:send_signature_requests).with([s1], delay_seconds: 5.seconds)
    end
  end

  describe '.normalize_email' do
    it 'returns fixed email when typo fixer changes the domain' do
      allow(EmailTypo).to receive(:call).with('user@gmial.com').and_return('user@gmail.com')

      expect(described_class.normalize_email('user@gmial.com')).to eq('user@gmail.com')
    end

    it 'returns nil for blank string' do
      expect(described_class.normalize_email('')).to be_nil
    end

    it 'returns original downcased when domain is excluded TLD' do
      expect(described_class.normalize_email('User@Example.gob')).to eq('user@example.gob')
    end

    it 'returns downcased input when address has no domain part' do
      expect(described_class.normalize_email('User@example')).to eq('user@example')
    end

    it 'returns downcased input when typo fixer matches original' do
      allow(EmailTypo).to receive(:call).with('user@example.com').and_return('user@example.com')

      expect(described_class.normalize_email('user@example.com')).to eq('user@example.com')
    end

    it 'skips fix when Levenshtein distance is too large' do
      allow(EmailTypo).to receive(:call).with('user@verydifferent.com').and_return('user@nothingalike.io')
      allow(Rails.logger).to receive(:info)

      expect(described_class.normalize_email('user@verydifferent.com')).to eq('user@verydifferent.com')
      expect(Rails.logger).to have_received(:info).with(/Skipped email fix/)
    end

    it 'skips fix when domain becomes gmail.<extension> but not gmail.com' do
      allow(EmailTypo).to receive(:call).with('user@gmail.coom').and_return('user@gmail.coo')

      result = described_class.normalize_email('user@gmail.coom')

      expect(result).to eq('user@gmail.coom')
    end

    it 'replaces slashes with commas before checking comma branch' do
      expect(described_class.normalize_email('A@b.com/C@d.com')).to eq('a@b.com,c@d.com')
    end
  end

  describe '.parse_emails' do
    it 'returns nil-safe empty array for nil' do
      expect(described_class.parse_emails(nil, nil)).to eq([])
    end
  end

  describe '.plain_search' do
    it 'returns original scope when keyword is blank' do
      scope = double('scope')

      expect(described_class.plain_search(scope, '')).to eq(scope)
    end

    it 'adds template join when search_template is enabled' do
      scope = Submission.all

      sql = described_class.plain_search(scope, 'foo', search_template: true).to_sql

      expect(sql).to include('%foo%')
      expect(sql.downcase).to include('templates')
    end

    it 'adds submitter values matcher when search_values is enabled' do
      scope = Submission.all

      sql = described_class.plain_search(scope, 'foo', search_values: true).to_sql

      expect(sql).to include('%foo%')
      expect(sql).to include('values')
    end
  end

  describe '.fulltext_search' do
    it 'returns original scope when keyword is blank' do
      scope = double('scope')
      user = double('user')

      expect(described_class.fulltext_search(user, scope, '')).to eq(scope)
    end
  end

  describe '.search delegating to fulltext' do
    it 'delegates to fulltext_search when enabled' do
      allow(Docuseal).to receive(:fulltext_search?).and_return(true)
      allow(described_class).to receive(:fulltext_search).and_return(:full_scope)

      expect(described_class.search(double('user'), :scope, 'abc', search_template: true)).to eq(:full_scope)
      expect(described_class).to have_received(:fulltext_search).with(anything, :scope, 'abc', search_template: true)
    end
  end

  describe '.check_item_conditions OR vs AND logic' do
    it 'returns true when AND result has all truthy values' do
      item = {
        'conditions' => [
          { 'field_uuid' => 'f1', 'action' => 'not_empty' },
          { 'field_uuid' => 'f2', 'action' => 'not_empty' }
        ]
      }
      values = { 'f1' => 'x', 'f2' => 'y' }
      fields_index = { 'f1' => { 'submitter_uuid' => 's1' }, 'f2' => { 'submitter_uuid' => 's1' } }
      allow(Submitters::SubmitValues).to receive(:check_field_condition).and_return(true)

      expect(described_class.check_item_conditions(item, values, fields_index)).to be(true)
    end

    it 'returns false when AND has any falsy condition' do
      item = {
        'conditions' => [
          { 'field_uuid' => 'f1', 'action' => 'not_empty' },
          { 'field_uuid' => 'f2', 'action' => 'not_empty' }
        ]
      }
      values = { 'f1' => 'x', 'f2' => '' }
      fields_index = { 'f1' => { 'submitter_uuid' => 's1' }, 'f2' => { 'submitter_uuid' => 's1' } }
      allow(Submitters::SubmitValues).to receive(:check_field_condition).and_return(true, false)

      expect(described_class.check_item_conditions(item, values, fields_index)).to be(false)
    end

    it 'collects submitter conditions accumulator' do
      item = {
        'conditions' => [{ 'field_uuid' => 'f1', 'action' => 'not_empty' }]
      }
      values = {}
      fields_index = { 'f1' => { 'submitter_uuid' => 's1' } }
      acc = []

      described_class.check_item_conditions(item, values, fields_index,
                                            include_submitter_uuid: 's1', submitter_conditions_acc: acc)

      expect(acc).to eq([{ 'field_uuid' => 'f1', 'action' => 'not_empty' }])
    end
  end

  describe '.filtered_conditions_fields' do
    it 'returns only the requested submitter fields when only_submitter_fields is true' do
      submission = double('submission',
                          template_fields: [
                            { 'submitter_uuid' => 's1', 'uuid' => 'f1' },
                            { 'submitter_uuid' => 's2', 'uuid' => 'f2' }
                          ])
      submitter = double('submitter', uuid: 's1', submission: submission)

      result = described_class.filtered_conditions_fields(submitter)

      expect(result.map { |f| f['uuid'] }).to eq(['f1'])
    end

    it 'filters out fields whose conditions are not met' do
      submission = double('submission',
                          template_fields: [
                            {
                              'submitter_uuid' => 's1', 'uuid' => 'f1',
                              'conditions' => [{ 'field_uuid' => 'f2', 'action' => 'not_empty' }]
                            }
                          ],
                          submitters: [double('s', values: { 'f2' => '' })],
                          fields_uuid_index: { 'f2' => { 'submitter_uuid' => 's2' } })
      submitter = double('submitter', uuid: 's1', submission: submission)
      allow(Submitters::SubmitValues).to receive(:check_field_condition).and_return(false)

      expect(described_class.filtered_conditions_fields(submitter)).to eq([])
    end
  end

  describe '.update_template_fields!' do
    it 'copies fields, schema, variables_schema from template and saves submission' do
      template = double('template', fields: ['f'], variables_schema: ['v'], schema: ['s'], submitters: ['sub'])
      submission = double('submission', template: template, template_submitters: nil)
      allow(submission).to receive(:template_fields=)
      allow(submission).to receive(:variables_schema=)
      allow(submission).to receive(:template_schema=)
      allow(submission).to receive(:template_submitters=)
      allow(submission).to receive(:save!)

      described_class.update_template_fields!(submission)

      expect(submission).to have_received(:template_fields=).with(['f'])
      expect(submission).to have_received(:variables_schema=).with(['v'])
      expect(submission).to have_received(:template_schema=).with(['s'])
      expect(submission).to have_received(:template_submitters=).with(['sub'])
      expect(submission).to have_received(:save!)
    end

    it 'preserves existing template_submitters when present' do
      template = double('template', fields: [], variables_schema: [], schema: [], submitters: [])
      submission = double('submission', template: template, template_submitters: ['existing'])
      allow(submission).to receive(:template_fields=)
      allow(submission).to receive(:variables_schema=)
      allow(submission).to receive(:template_schema=)
      allow(submission).to receive(:template_submitters=)
      allow(submission).to receive(:save!)

      described_class.update_template_fields!(submission)

      expect(submission).not_to have_received(:template_submitters=)
    end
  end

  describe '.preload_with_pages' do
    it 'preloads schema documents with blobs and preview images, returns submission' do
      submission = double('submission', schema_documents: [:doc])
      preloader = double('preloader', call: true)
      allow(ActiveRecord::Associations::Preloader).to receive(:new).and_return(preloader)

      expect(described_class.preload_with_pages(submission)).to eq(submission)
      expect(preloader).to have_received(:call)
    end
  end

  describe '.send_signature_requests order-preserved branch' do
    it 'sends only to the first remaining ordered submitter when order is preserved' do
      s1 = double('s1', uuid: 'u1', completed_at?: false)
      submission = double(
        'submission',
        template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
        submitters: [s1, double('s2', uuid: 'u2', completed_at?: false)],
        submitters_order_preserved?: true
      )
      allow(Submitters).to receive(:send_signature_requests)

      described_class.send_signature_requests([submission])

      expect(Submitters).to have_received(:send_signature_requests).with([s1], delay_seconds: nil)
    end

    it 'sends to all pending submitters when no order is enforced' do
      s1 = double('s1', uuid: 'u1', completed_at?: false)
      s2 = double('s2', uuid: 'u2', completed_at?: false)
      submission = double(
        'submission',
        template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
        submitters: [s1, s2],
        submitters_order_preserved?: false
      )
      allow(Submitters).to receive(:send_signature_requests)

      described_class.send_signature_requests([submission])

      expect(Submitters).to have_received(:send_signature_requests).with([s1, s2], delay_seconds: nil)
    end
  end
end
