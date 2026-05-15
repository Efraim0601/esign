# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ability do
  def build_ability_for(role:, account_id: 10, user_id: 99)
    user = build_stubbed(:user, role:, account_id:, id: user_id)
    described_class.new(user)
  end

  before do
    # `Ability` appelle `Abilities::TemplateConditions` dès l'initialisation.
    # Pour un test RBAC, on isole les règles de rôle (viewer/agent/member/editor/admin)
    # et on évite de coupler ces specs à la logique de filtrage des templates.
    allow(Abilities::TemplateConditions).to receive(:collection).and_return(nil)
    allow(Abilities::TemplateConditions).to receive(:entity).and_return(true)
  end

  describe 'AFB RBAC restriction layer' do
    it 'restricts viewer to read-only access for templates/submissions/users' do
      ability = build_ability_for(role: 'viewer')

      own_template = Template.new(account_id: 10, author_id: 99)
      other_template = Template.new(account_id: 10, author_id: 123)

      expect(ability.can?(:read, own_template)).to be(true)
      expect(ability.can?(:create, Template.new(account_id: 10))).to be(true)
      expect(ability.can?(:update, own_template)).to be(false)
      expect(ability.can?(:destroy, other_template)).to be(false)

      submission_in_account = Submission.new(account_id: 10)
      submission_other_account = Submission.new(account_id: 11)
      expect(ability.can?(:read, submission_in_account)).to be(true)
      expect(ability.can?(:read, submission_other_account)).to be(false)

      expect(ability.can?(:manage, TemplateFolder.new(account_id: 10))).to be(false)
      expect(ability.can?(:manage, TemplateSharing.new(template: Template.new(account_id: 10)))).to be(false)
      expect(ability.can?(:manage, :mcp)).to be(false)
      expect(ability.can?(:manage, AccessToken.new(user_id: 99))).to be(false)
    end

    it 'allows agent to manage only own templates and own submissions' do
      ability = build_ability_for(role: 'agent')

      own_template = Template.new(account_id: 10, author_id: 99)
      other_template = Template.new(account_id: 10, author_id: 123)

      expect(ability.can?(:read, own_template)).to be(true)
      expect(ability.can?(:update, own_template)).to be(true)
      expect(ability.can?(:destroy, own_template)).to be(true)
      expect(ability.can?(:update, other_template)).to be(false)
      expect(ability.can?(:destroy, other_template)).to be(false)

      own_submission = Submission.new(account_id: 10, created_by_user_id: 99)
      other_submission = Submission.new(account_id: 10, created_by_user_id: 123)

      expect(ability.can?(:create, Submission.new(account_id: 10))).to be(true)
      expect(ability.can?(:read, own_submission)).to be(true)
      expect(ability.can?(:read, other_submission)).to be(false)
      expect(ability.can?(:cancel, own_submission)).to be(true)
      expect(ability.can?(:cancel, other_submission)).to be(false)
    end

    it 'allows member to read all submissions in account but restricts bulk_send templates' do
      ability = build_ability_for(role: 'member')

      template = Template.new(account_id: 10, author_id: 99)
      expect(ability.can?(:bulk_send, template)).to be(false)

      any_submission = Submission.new(account_id: 10, created_by_user_id: 123)
      expect(ability.can?(:read, any_submission)).to be(true)
      expect(ability.can?(:update, any_submission)).to be(false)
    end

    it 'allows editor to manage submissions but disallows activity log export' do
      ability = build_ability_for(role: 'editor')

      submission = Submission.new(account_id: 10, created_by_user_id: 123)
      expect(ability.can?(:manage, submission)).to be(true)
      expect(ability.can?(:export, :activity_log)).to be(false)
    end

    it 'allows admin to manage users within the account' do
      ability = build_ability_for(role: 'admin', account_id: 10, user_id: 99)

      other_user_same_account = User.new(account_id: 10, id: 123)
      other_user_other_account = User.new(account_id: 11, id: 124)

      expect(ability.can?(:manage, other_user_same_account)).to be(true)
      expect(ability.can?(:manage, other_user_other_account)).to be(false)
    end

  end
end

