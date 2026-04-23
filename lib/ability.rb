# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    can %i[read create], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end

    can :destroy, Template, account_id: user.account_id
    can :manage, TemplateFolder, account_id: user.account_id
    can :manage, TemplateSharing, template: { account_id: user.account_id }
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id

    can :manage, :mcp

    other_user_in_account = ->(other) { other.is_a?(User) && other.account_id == user.account_id && other.id != user.id }

    # AFB RBAC restriction layer
    case user.role
    when 'viewer'
      # Template: read only (no update, no destroy)
      cannot :update, Template
      cannot :destroy, Template
      # Submission: read only
      can :read, Submission, account_id: user.account_id
      # Submitter: read only
      can :read, Submitter, account_id: user.account_id
      # User: read own, no manage others
      can :read, User, account_id: user.account_id
      can :update, User, id: user.id
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
      cannot :manage, Account, id: user.account_id

    when 'agent'
      # Template: read only (no update, no destroy)
      cannot :update, Template
      cannot :destroy, Template
      # Submission: read own, create, update own, etc.
      can :read, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :create, Submission, account_id: user.account_id
      can :update, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :destroy, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :cancel, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :resend, Submission, account_id: user.account_id, created_by_user_id: user.id
      # Submitter: manage own submissions' submitters
      can %i[create update destroy], Submitter, submission: { account_id: user.account_id, created_by_user_id: user.id }
      # User: read own, no manage others
      can :read, User, account_id: user.account_id
      can :update, User, id: user.id
      cannot :create, User, account_id: user.account_id
      cannot :manage, User, &other_user_in_account
      cannot :manage, EncryptedConfig
      cannot :manage, AccountConfig
      cannot :manage, WebhookUrl
      cannot :manage, AccessToken
      cannot :manage, Account, id: user.account_id

    when 'member'
      # Template: read, create only. Cannot update any. Destroy only own.
      cannot :update, Template
      cannot :destroy, Template
      can :destroy, Template, account_id: user.account_id, author_id: user.id
      can :manage, TemplateFolder, account_id: user.account_id
      can :manage, TemplateSharing, template: { account_id: user.account_id }
      cannot :bulk_send, Template
      # Submission: read all, create, update own, etc.
      can :read, Submission, account_id: user.account_id
      can :create, Submission, account_id: user.account_id
      can :update, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :destroy, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :cancel, Submission, account_id: user.account_id, created_by_user_id: user.id
      can :resend, Submission, account_id: user.account_id, created_by_user_id: user.id
      # Submitter: manage own submissions' submitters
      can %i[create update destroy], Submitter, submission: { account_id: user.account_id, created_by_user_id: user.id }
      # User: read own, no manage others
      can :read, User, account_id: user.account_id
      can :update, User, id: user.id
      cannot :create, User, account_id: user.account_id
      cannot :manage, User, &other_user_in_account
      cannot :manage, EncryptedConfig
      cannot :manage, AccountConfig
      cannot :manage, WebhookUrl
      cannot :manage, AccessToken
      cannot :manage, Account, id: user.account_id

    when 'editor'
      # Template: manage all
      can :update, Template, Abilities::TemplateConditions.collection(user) do |template|
        Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
      end
      can :manage, TemplateFolder, account_id: user.account_id
      can :manage, TemplateSharing, template: { account_id: user.account_id }
      # Submission: manage all
      can :manage, Submission, account_id: user.account_id
      # Submitter: manage all
      can :manage, Submitter, account_id: user.account_id
      # User: read own, no manage others
      can :read, User, account_id: user.account_id
      can :update, User, id: user.id
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
      can :update, Template, Abilities::TemplateConditions.collection(user) do |template|
        Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
      end
      can :manage, TemplateFolder, account_id: user.account_id
      can :manage, TemplateSharing, template: { account_id: user.account_id }
      can :manage, Submission, account_id: user.account_id
      can :manage, Submitter, account_id: user.account_id
      can :manage, User, account_id: user.account_id
    end
  end
end
