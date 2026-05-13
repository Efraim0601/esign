# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::Clone do
  describe '.update_submitters_and_fields_and_schema' do
    it 'replaces submitter and field uuids across fields, schema and preferences' do
      submitters = [
        {
          'uuid' => 's1',
          'optional_invite_by_uuid' => 's2',
          'invite_by_uuid' => 's2',
          'linked_to_uuid' => 's2',
          'invite_via_field_uuid' => 'f1'
        },
        { 'uuid' => 's2' }
      ]
      fields = [
        {
          'uuid' => 'f1',
          'submitter_uuid' => 's1',
          'conditions' => [{ 'field_uuid' => 'f1' }],
          'preferences' => { 'formula' => 'f1 + 10' }
        }
      ]
      schema = [{ 'conditions' => [{ 'field_uuid' => 'f1' }] }]
      preferences = { 'submitters' => [{ 'uuid' => 's1' }, { 'uuid' => 's2' }] }

      allow(SecureRandom).to receive(:uuid).and_return('ns1', 'ns2', 'nf1')

      cloned_submitters, cloned_fields, cloned_schema, cloned_preferences =
        described_class.update_submitters_and_fields_and_schema(submitters, fields, schema, preferences)

      expect(cloned_submitters.map { |s| s['uuid'] }).to eq(%w[ns1 ns2])
      expect(cloned_submitters.first['invite_by_uuid']).to eq('ns2')
      expect(cloned_submitters.first['optional_invite_by_uuid']).to eq('ns2')
      expect(cloned_submitters.first['linked_to_uuid']).to eq('ns2')
      expect(cloned_submitters.first['invite_via_field_uuid']).to eq('nf1')

      expect(cloned_fields.first['uuid']).to eq('nf1')
      expect(cloned_fields.first['submitter_uuid']).to eq('ns1')
      expect(cloned_fields.first['conditions'].first['field_uuid']).to eq('nf1')
      expect(cloned_fields.first['preferences']['formula']).to include('nf1')

      expect(cloned_schema.first['conditions'].first['field_uuid']).to eq('nf1')
      expect(cloned_preferences['submitters'].map { |s| s['uuid'] }).to eq(%w[ns1 ns2])
    end
  end
end
