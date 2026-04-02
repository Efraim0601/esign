# frozen_string_literal: true

RSpec.describe Ability do
  let(:account) { create(:account) }

  let(:template_owned) { create(:template, account:, author: user, folder: create(:template_folder, account:, author: user)) }
  let(:template_other) do
    other_author = create(:user, account:, role: 'admin')
    create(:template, account:, author: other_author, folder: create(:template_folder, account:, author: other_author))
  end

  let(:submission_owned) { create(:submission, template: template_owned, created_by_user: user) }
  let(:submission_other) do
    other_creator = create(:user, account:, role: 'admin')
    create(:submission, template: template_other, created_by_user: other_creator, account_id: account.id)
  end

  let!(:submitter_owned) { create(:submitter, submission: submission_owned) }
  let!(:submitter_other) { create(:submitter, submission: submission_other) }

  def expect_can(action, subject)
    expect(ability.can?(action, subject)).to eq(true)
  end

  def expect_cannot(action, subject)
    expect(ability.can?(action, subject)).to eq(false)
  end

  shared_examples 'AFB matrix' do |expected|
    it('Accéder aux paramètres généraux (Settings)') do
      expected[:settings] ? expect_can(:manage, account) : expect_cannot(:manage, account)
    end

    it('Configurer le SMTP (email)') do
      config = create(:encrypted_config, account:)
      expected[:smtp] ? expect_can(:manage, config) : expect_cannot(:manage, config)
    end

    it('Configurer le branding (logo, couleurs)') do
      cfg = create(:account_config, account:)
      expected[:branding] ? expect_can(:manage, cfg) : expect_cannot(:manage, cfg)
    end

    it('Gérer les webhooks') do
      webhook = create(:webhook_url, account:)
      expected[:webhooks] ? expect_can(:manage, webhook) : expect_cannot(:manage, webhook)
    end

    it('Accéder à la clé API') do
      token = user.access_token
      expected[:api_key] ? expect_can(:manage, token) : expect_cannot(:manage, token)
    end

    it('Configurer le stockage fichiers') do
      config = create(:encrypted_config, account:)
      expected[:storage] ? expect_can(:manage, config) : expect_cannot(:manage, config)
    end

    it('Configurer les rappels automatiques') do
      cfg = create(:account_config, account:)
      expected[:reminders] ? expect_can(:manage, cfg) : expect_cannot(:manage, cfg)
    end

    it('Changer la langue de l’interface') do
      expected[:language] ? expect_can(:manage, account) : expect_cannot(:manage, account)
    end

    it('Voir la liste des utilisateurs') do
      expected[:users_manage] ? expect_can(:manage, create(:user, account:, role: 'agent')) : expect_cannot(:manage, create(:user, account:, role: 'agent'))
    end

    it('Inviter un nouvel utilisateur') do
      expected[:users_manage] ? expect_can(:create, User.new(account:)) : expect_cannot(:create, User.new(account:))
    end

    it('Modifier le rôle d’un utilisateur') do
      expected[:users_manage] ? expect_can(:update, create(:user, account:, role: 'agent')) : expect_cannot(:update, create(:user, account:, role: 'agent'))
    end

    it('Désactiver / réactiver un utilisateur') do
      expected[:users_manage] ? expect_can(:update, create(:user, account:, role: 'agent')) : expect_cannot(:update, create(:user, account:, role: 'agent'))
    end

    it('Supprimer un utilisateur') do
      expected[:users_manage] ? expect_can(:destroy, create(:user, account:, role: 'agent')) : expect_cannot(:destroy, create(:user, account:, role: 'agent'))
    end

    it('Voir tous les templates') do
      expected[:templates_read_all] ? expect_can(:read, template_other) : expect_cannot(:read, template_other)
    end

    it('Créer un nouveau template') do
      expected[:templates_create] ? expect_can(:create, Template.new(account_id: account.id, author: user)) : expect_cannot(:create, Template.new(account_id: account.id, author: user))
    end

    it('Modifier un template (champs, rôles, ordre) — sur un template des autres') do
      expected[:templates_update_other] ? expect_can(:update, template_other) : expect_cannot(:update, template_other)
    end

    it('Modifier un template (champs, rôles, ordre) — sur son propre template') do
      expected[:templates_update_own] ? expect_can(:update, template_owned) : expect_cannot(:update, template_owned)
    end

    it('Supprimer un template — sur un template des autres') do
      expected[:templates_destroy_other] ? expect_can(:destroy, template_other) : expect_cannot(:destroy, template_other)
    end

    it('Supprimer un template — sur son propre template') do
      expected[:templates_destroy_own] ? expect_can(:destroy, template_owned) : expect_cannot(:destroy, template_owned)
    end

    it('Dupliquer un template') do
      expected[:templates_duplicate] ? expect_can(:create, Template.new(account_id: account.id, author: user)) : expect_cannot(:create, Template.new(account_id: account.id, author: user))
    end

    it('Organiser les templates en dossiers') do
      folder = create(:template_folder, account:, author: user)
      expected[:template_folders_manage] ? expect_can(:manage, folder) : expect_cannot(:manage, folder)
    end

    it('Marquer un template comme privé') do
      expected[:templates_mark_private] ? expect_can(:update, template_owned) : expect_cannot(:update, template_owned)
    end

    it('Configurer l’expiration d’un template') do
      expected[:templates_expiration] ? expect_can(:update, template_owned) : expect_cannot(:update, template_owned)
    end

    it('Envoyer un document en signature (depuis un template)') do
      expected[:submissions_create] ? expect_can(:create, Submission.new(account_id: account.id, created_by_user: user, template: template_other)) : expect_cannot(:create, Submission.new(account_id: account.id, created_by_user: user, template: template_other))
    end

    it('Voir toutes les soumissions (sur une soumission des autres)') do
      expected[:submissions_read_all] ? expect_can(:read, submission_other) : expect_cannot(:read, submission_other)
    end

    it('Voir ses propres soumissions') do
      expected[:submissions_read_own] ? expect_can(:read, submission_owned) : expect_cannot(:read, submission_owned)
    end

    it('Modifier les infos d’un signataire avant signature — sur un signataire des autres') do
      expected[:submitters_update_other] ? expect_can(:update, submitter_other) : expect_cannot(:update, submitter_other)
    end

    it('Modifier les infos d’un signataire avant signature — sur son propre signataire') do
      expected[:submitters_update_own] ? expect_can(:update, submitter_owned) : expect_cannot(:update, submitter_owned)
    end

    it('Renvoyer une invitation (rappel manuel) — sur une soumission des autres') do
      expected[:submissions_resend_other] ? expect_can(:resend, submission_other) : expect_cannot(:resend, submission_other)
    end

    it('Renvoyer une invitation (rappel manuel) — sur sa propre soumission') do
      expected[:submissions_resend_own] ? expect_can(:resend, submission_owned) : expect_cannot(:resend, submission_owned)
    end

    it('Annuler une soumission en cours — sur une soumission des autres') do
      expected[:submissions_cancel_other] ? expect_can(:cancel, submission_other) : expect_cannot(:cancel, submission_other)
    end

    it('Annuler une soumission en cours — sur sa propre soumission') do
      expected[:submissions_cancel_own] ? expect_can(:cancel, submission_owned) : expect_cannot(:cancel, submission_owned)
    end

    it('Ajouter un destinataire BCC — sur une soumission des autres') do
      expected[:submissions_update_other] ? expect_can(:update, submission_other) : expect_cannot(:update, submission_other)
    end

    it('Ajouter un destinataire BCC — sur sa propre soumission') do
      expected[:submissions_update_own] ? expect_can(:update, submission_owned) : expect_cannot(:update, submission_owned)
    end

    it('Envoi en masse (bulk send)') do
      expected[:bulk_send] ? expect_can(:bulk_send, Template) : expect_cannot(:bulk_send, Template)
    end

    it('Télécharger un document signé (ses propres soumissions)') do
      expected[:download_own] ? expect_can(:read, submission_owned) : expect_cannot(:read, submission_owned)
    end

    it('Télécharger un document signé (toutes les soumissions)') do
      expected[:download_all] ? expect_can(:read, submission_other) : expect_cannot(:read, submission_other)
    end

    it('Rechercher dans les archives') do
      expected[:search_archives] ? expect_can(:read, submission_other) : expect_cannot(:read, submission_other)
    end

    it('Consulter la piste d’audit d’un document') do
      expected[:audit_trail] ? expect_can(:read, submission_other) : expect_cannot(:read, submission_other)
    end

    it('Consulter l’historique global des soumissions') do
      expected[:submissions_history] ? expect_can(:read, submission_other) : expect_cannot(:read, submission_other)
    end

    it("Exporter les logs d’activité") do
      expected[:export_activity_log] ? expect_can(:export, :activity_log) : expect_cannot(:export, :activity_log)
    end
  end

  describe 'viewer role' do
    let(:user) { create(:user, role: 'viewer', account:) }
    let(:ability) { described_class.new(user) }

    include_examples 'AFB matrix',
                     settings: false,
                     smtp: false,
                     branding: false,
                     webhooks: false,
                     api_key: false,
                     storage: false,
                     reminders: false,
                     language: false,
                     users_manage: false,
                     templates_read_all: true,
                     templates_create: false,
                     templates_update_other: false,
                     templates_update_own: false,
                     templates_destroy_other: false,
                     templates_destroy_own: false,
                     templates_duplicate: false,
                     template_folders_manage: false,
                     templates_mark_private: false,
                     templates_expiration: false,
                     submissions_create: false,
                     submissions_read_all: true,
                     submissions_read_own: true,
                     submitters_update_other: false,
                     submitters_update_own: false,
                     submissions_resend_other: false,
                     submissions_resend_own: false,
                     submissions_cancel_other: false,
                     submissions_cancel_own: false,
                     submissions_update_other: false,
                     submissions_update_own: false,
                     bulk_send: false,
                     download_own: true,
                     download_all: true,
                     search_archives: true,
                     audit_trail: true,
                     submissions_history: true,
                     export_activity_log: false
  end

  describe 'agent role' do
    let(:user) { create(:user, role: 'agent', account:) }
    let(:ability) { described_class.new(user) }

    include_examples 'AFB matrix',
                     settings: false,
                     smtp: false,
                     branding: false,
                     webhooks: false,
                     api_key: false,
                     storage: false,
                     reminders: false,
                     language: false,
                     users_manage: false,
                     templates_read_all: true,
                     templates_create: false,
                     templates_update_other: false,
                     templates_update_own: false,
                     templates_destroy_other: false,
                     templates_destroy_own: false,
                     templates_duplicate: false,
                     template_folders_manage: false,
                     templates_mark_private: false,
                     templates_expiration: false,
                     submissions_create: true,
                     submissions_read_all: false,
                     submissions_read_own: true,
                     submitters_update_other: false,
                     submitters_update_own: true,
                     submissions_resend_other: false,
                     submissions_resend_own: true,
                     submissions_cancel_other: false,
                     submissions_cancel_own: true,
                     submissions_update_other: false,
                     submissions_update_own: true,
                     bulk_send: false,
                     download_own: true,
                     download_all: false,
                     search_archives: true,
                     audit_trail: true,
                     submissions_history: false,
                     export_activity_log: false
  end

  describe 'member role' do
    let(:user) { create(:user, role: 'member', account:) }
    let(:ability) { described_class.new(user) }

    include_examples 'AFB matrix',
                     settings: false,
                     smtp: false,
                     branding: false,
                     webhooks: false,
                     api_key: false,
                     storage: false,
                     reminders: false,
                     language: false,
                     users_manage: false,
                     templates_read_all: true,
                     templates_create: true,
                     templates_update_other: false,
                     templates_update_own: true,
                     templates_destroy_other: false,
                     templates_destroy_own: true,
                     templates_duplicate: true,
                     template_folders_manage: true,
                     templates_mark_private: true,
                     templates_expiration: true,
                     submissions_create: true,
                     submissions_read_all: true,
                     submissions_read_own: true,
                     submitters_update_other: false,
                     submitters_update_own: true,
                     submissions_resend_other: false,
                     submissions_resend_own: true,
                     submissions_cancel_other: false,
                     submissions_cancel_own: true,
                     submissions_update_other: false,
                     submissions_update_own: true,
                     bulk_send: false,
                     download_own: true,
                     download_all: true,
                     search_archives: true,
                     audit_trail: true,
                     submissions_history: true,
                     export_activity_log: false
  end

  describe 'editor role' do
    let(:user) { create(:user, role: 'editor', account:) }
    let(:ability) { described_class.new(user) }

    include_examples 'AFB matrix',
                     settings: false,
                     smtp: false,
                     branding: false,
                     webhooks: false,
                     api_key: false,
                     storage: false,
                     reminders: false,
                     language: false,
                     users_manage: false,
                     templates_read_all: true,
                     templates_create: true,
                     templates_update_other: true,
                     templates_update_own: true,
                     templates_destroy_other: true,
                     templates_destroy_own: true,
                     templates_duplicate: true,
                     template_folders_manage: true,
                     templates_mark_private: true,
                     templates_expiration: true,
                     submissions_create: true,
                     submissions_read_all: true,
                     submissions_read_own: true,
                     submitters_update_other: true,
                     submitters_update_own: true,
                     submissions_resend_other: true,
                     submissions_resend_own: true,
                     submissions_cancel_other: true,
                     submissions_cancel_own: true,
                     submissions_update_other: true,
                     submissions_update_own: true,
                     bulk_send: true,
                     download_own: true,
                     download_all: true,
                     search_archives: true,
                     audit_trail: true,
                     submissions_history: true,
                     export_activity_log: false
  end

  describe 'admin role' do
    let(:user) { create(:user, role: 'admin', account:) }
    let(:ability) { described_class.new(user) }

    include_examples 'AFB matrix',
                     settings: true,
                     smtp: true,
                     branding: true,
                     webhooks: true,
                     api_key: true,
                     storage: true,
                     reminders: true,
                     language: true,
                     users_manage: true,
                     templates_read_all: true,
                     templates_create: true,
                     templates_update_other: true,
                     templates_update_own: true,
                     templates_destroy_other: true,
                     templates_destroy_own: true,
                     templates_duplicate: true,
                     template_folders_manage: true,
                     templates_mark_private: true,
                     templates_expiration: true,
                     submissions_create: true,
                     submissions_read_all: true,
                     submissions_read_own: true,
                     submitters_update_other: true,
                     submitters_update_own: true,
                     submissions_resend_other: true,
                     submissions_resend_own: true,
                     submissions_cancel_other: true,
                     submissions_cancel_own: true,
                     submissions_update_other: true,
                     submissions_update_own: true,
                     bulk_send: true,
                     download_own: true,
                     download_all: true,
                     search_archives: true,
                     audit_trail: true,
                     submissions_history: true,
                     export_activity_log: true
  end
end

