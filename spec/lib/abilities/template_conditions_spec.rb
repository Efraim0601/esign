# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Abilities::TemplateConditions do
  describe '.entity' do
    it 'returns true when template belongs to same account' do
      user = double('user', account_id: 1, id: 2, role: 'member')
      template = double('template', account_id: 1)

      expect(described_class.entity(template, user: user)).to be(true)
    end

    it 'returns false for private template not owned by user non-admin' do
      linked_account = double('linked_account')
      account = double('account', linked_account_account: linked_account)
      user = double('user', account_id: 2, id: 10, role: 'member', account: account)
      sharing = double('sharing', account_id: TemplateSharing::ALL_ID, ability: 'read')
      template = double('template', account_id: 1, private?: true, author_id: 42, template_sharings: [sharing])

      expect(described_class.entity(template, user: user)).to be(false)
    end

    it 'returns true when shared template has matching ability' do
      linked_account = double('linked_account')
      account = double('account', linked_account_account: linked_account)
      user = double('user', account_id: 2, id: 10, role: 'member', account: account)
      sharing = double('sharing', account_id: 2, ability: 'manage')
      template = double('template', account_id: 1, private?: false, author_id: 42, template_sharings: [sharing])

      expect(described_class.entity(template, user: user, ability: 'read')).to be(true)
    end
  end
end
