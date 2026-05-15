# frozen_string_literal: true

module Abilities
  module TemplateConditions
    module_function

    def collection(user, ability: nil)
      templates = Template.where(account_id: user.account_id)

      # Filter private templates: only author or admin can see them
      templates = templates.where('private = false OR author_id = ? OR ? = ?', user.id, user.role, 'admin')

      return templates unless user.account.testing?

      shared_ids =
        TemplateSharing.where({ ability:, account_id: [user.account_id, TemplateSharing::ALL_ID] }.compact)
                       .select(:template_id)

      Template.where(Template.arel_table[:id].in(templates.select(:id).arel.union(:all, shared_ids.arel)))
    end

    def entity(template, user:, ability: nil)
      return true if template.account_id.blank?
      return true if template.account_id == user.account_id

      # Private templates are only accessible by author or admin
      return false if template.private? && template.author_id != user.id && user.role != 'admin'

      return false unless user.account.linked_account_account
      return false if template.template_sharings.to_a.blank?

      account_ids = [user.account_id, TemplateSharing::ALL_ID]

      template.template_sharings.to_a.any? do |e|
        e.account_id.in?(account_ids) && (ability.nil? || e.ability == 'manage' || e.ability == ability)
      end
    end
  end
end
