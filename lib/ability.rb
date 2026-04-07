# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end

    can :destroy, Template, account_id: user.account_id
    can :manage, TemplateFolder, account_id: user.account_id
    can :manage, TemplateSharing, template: { account_id: user.account_id }
    can :manage, Submission, account_id: user.account_id
    can :manage, Submitter, account_id: user.account_id
    can :manage, User, account_id: user.account_id
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id

    can :manage, :mcp

    not_own_submission = ['account_id = ? AND created_by_user_id IS DISTINCT FROM ?', user.account_id, user.id]
    submitter_on_foreign_submission = [
      'submission_id IN (SELECT id FROM submissions WHERE account_id = ? AND created_by_user_id IS DISTINCT FROM ?)',
      user.account_id,
      user.id
    ]
    other_user_in_account = ->(other) { other.is_a?(User) && other.account_id == user.account_id && other.id != user.id }

    # AFB RBAC restriction layer
    case user.role
    when 'viewer'
      cannot :create, Template
      cannot :bulk_send, Template
      cannot :update, Template
      cannot :destroy, Template
      cannot :create, Submission
      cannot :update, Submission
      cannot :destroy, Submission
      can :read, Submission, account_id: user.account_id
      cannot :create, User, account_id: user.account_id
      cannot :manage, User, &other_user_in_account
      cannot :manage, EncryptedConfig
      cannot :manage, AccountConfig
      cannot :manage, WebhookUrl
      cannot :manage, AccessToken
      cannot :manage, McpToken, user_id: user.id
      cannot :manage, :mcp
      cannot :manage, TemplateFolder, account_id: user.account_id
      cannot :manage, TemplateSharing, template: { account_id: user.account_id }
      cannot :manage, Submitter, account_id: user.account_id
      cannot :manage, Account, id: user.account_id

    when 'agent'
      cannot :create, Template
      cannot :bulk_send, Template
      cannot :update, Template
      cannot :destroy, Template
      cannot :create, User, account_id: user.account_id
      cannot :manage, User, &other_user_in_account
      cannot :manage, EncryptedConfig
      cannot :manage, AccountConfig
      cannot :manage, WebhookUrl
      cannot :manage, AccessToken
      cannot :manage, Account, id: user.account_id
      cannot :read, Submission, not_own_submission
      cannot :update, Submission, not_own_submission
      cannot :destroy, Submission, not_own_submission
      cannot :cancel, Submission, not_own_submission
      cannot :resend, Submission, not_own_submission
      cannot %i[create update destroy], Submitter, submitter_on_foreign_submission

    when 'member'
      cannot :update, Template, ["author_id != ?", user.id]
      cannot :destroy, Template, ["author_id != ?", user.id]
      cannot :bulk_send, Template
      cannot :create, User, account_id: user.account_id
      cannot :manage, User, &other_user_in_account
      cannot :manage, EncryptedConfig
      cannot :manage, AccountConfig
      cannot :manage, WebhookUrl
      cannot :manage, AccessToken
      cannot :manage, Account, id: user.account_id
      cannot :update, Submission, not_own_submission
      cannot :destroy, Submission, not_own_submission
      cannot :cancel, Submission, not_own_submission
      cannot :resend, Submission, not_own_submission
      cannot %i[create update destroy], Submitter, submitter_on_foreign_submission

    when 'editor'
      cannot :create, User, account_id: user.account_id
      cannot :manage, User, &other_user_in_account
      cannot :manage, EncryptedConfig
      cannot :manage, AccountConfig
      cannot :manage, WebhookUrl
      cannot :manage, AccessToken
      cannot :manage, Account, id: user.account_id
      cannot :export, :activity_log

    when 'admin'
      # admin keeps all existing permissions — no restrictions
      nil
    end
  end
end
