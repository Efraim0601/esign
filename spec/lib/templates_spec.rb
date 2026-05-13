# frozen_string_literal: true

RSpec.describe Templates do
  describe '.build_field_areas_index' do
    it 'returns an empty hash when given no fields' do
      expect(described_class.build_field_areas_index([])).to eq({})
    end

    it 'groups areas by attachment_uuid then by page' do
      uuid = SecureRandom.uuid
      field = {
        'name' => 'Signature',
        'areas' => [
          { 'attachment_uuid' => uuid, 'page' => 0 },
          { 'attachment_uuid' => uuid, 'page' => 1 }
        ]
      }

      result = described_class.build_field_areas_index([field])

      expect(result.keys).to eq([uuid])
      expect(result[uuid].keys).to contain_exactly(0, 1)
      expect(result[uuid][0].first).to eq([field['areas'][0], field])
    end

    it 'skips fields with nil areas' do
      expect(described_class.build_field_areas_index([{ 'name' => 'X' }])).to eq({})
    end

    it 'aggregates multiple fields sharing the same page' do
      uuid = SecureRandom.uuid
      field_a = { 'areas' => [{ 'attachment_uuid' => uuid, 'page' => 0 }] }
      field_b = { 'areas' => [{ 'attachment_uuid' => uuid, 'page' => 0 }] }

      result = described_class.build_field_areas_index([field_a, field_b])

      expect(result[uuid][0].size).to eq(2)
    end
  end

  describe '.maybe_assign_access' do
    it 'returns nil (upstream-stub override hook)' do
      expect(described_class.maybe_assign_access(double)).to be_nil
    end
  end

  describe '.plain_search' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let!(:matching) { create(:template, account:, author:, name: 'Service Agreement') }
    let!(:non_matching) { create(:template, account:, author:, name: 'NDA') }

    it 'returns the relation unchanged when keyword is blank' do
      relation = account.templates
      expect(described_class.plain_search(relation, '')).to eq(relation)
      expect(described_class.plain_search(relation, nil)).to eq(relation)
    end

    it 'matches case-insensitively on the template name' do
      result = described_class.plain_search(account.templates, 'service')

      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end
  end

  describe '.filter_undefined_submitters' do
    it 'keeps only entries with no invitation/linking metadata' do
      submitters = [
        { 'name' => 'Plain' },
        { 'name' => 'WithEmail', 'email' => 'x@y.com' },
        { 'name' => 'WithInvite', 'invite_by_uuid' => SecureRandom.uuid },
        { 'name' => 'Linked', 'linked_to_uuid' => SecureRandom.uuid },
        { 'name' => 'Requester', 'is_requester' => true },
        { 'name' => 'OptionalInvite', 'optional_invite_by_uuid' => SecureRandom.uuid },
        { 'name' => 'FieldInvite', 'invite_via_field_uuid' => SecureRandom.uuid }
      ]

      result = described_class.filter_undefined_submitters(submitters)

      expect(result.map { |s| s['name'] }).to eq(['Plain'])
    end
  end

  describe '.build_default_expire_at' do
    let(:template) { build(:template) }

    it 'returns nil when no expire_at duration is configured' do
      template.preferences = {}
      expect(described_class.build_default_expire_at(template)).to be_nil
    end

    it 'parses an explicit specified_date' do
      template.preferences = { 'default_expire_at_duration' => 'specified_date',
                               'default_expire_at' => '2030-01-15T00:00:00Z' }

      expect(described_class.build_default_expire_at(template)).to eq(Time.zone.parse('2030-01-15T00:00:00Z'))
    end

    it 'returns nil for specified_date without an explicit date' do
      template.preferences = { 'default_expire_at_duration' => 'specified_date' }

      expect(described_class.build_default_expire_at(template)).to be_nil
    end

    it 'computes a future date for known duration keys' do
      freeze_time do
        template.preferences = { 'default_expire_at_duration' => 'seven_days' }

        expect(described_class.build_default_expire_at(template)).to eq(Time.current + 7.days)
      end
    end

    it 'returns nil for an unknown duration key' do
      template.preferences = { 'default_expire_at_duration' => 'forever' }

      expect(described_class.build_default_expire_at(template)).to be_nil
    end
  end
end
