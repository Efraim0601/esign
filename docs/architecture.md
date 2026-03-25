# Architecture (eSign)

## 1) Vue d'ensemble
Cette application est un monolithe **Ruby on Rails** qui gère :
1. la création de formulaires PDF (builder de champs),
2. l'envoi / le remplissage / la signature de formulaires par des "submitters",
3. la vérification des signatures PDF,
4. les emails, webhooks et exports autour des événements (création, complétion, refus, etc.),
5. une interface d'administration (dashboard, modèles, paramètres, intégrations).

Côté front, l'application utilise :
- les vues Rails en **ERB**,
- **Hotwire/Turbo**,
- **Shakapacker** pour le bundling JS,
- **Tailwind CSS + DaisyUI** (thème configuré via `tailwind.config.js`).

Le traitement asynchrone (webhooks, reindex recherche, traitements longs) s'appuie sur **Sidekiq**, lancé de manière embarquée via les plugins Puma.

## 2) Stack technique et positionnement
- **Rails** : routing, contrôleurs, vues, modèles ActiveRecord, validation/permissions (CanCanCan / CanCan).
- **Auth** : `devise_for :users`.
- **Multi-tenancy** : bascule de comportements via `Docuseal.multitenant?` (voir `config/routes.rb`).
- **Stockage** : ActiveStorage (proxy de blobs, urls publiques, etc.).
- **Background jobs** : Sidekiq embarqué (voir `lib/puma/plugin/sidekiq_embed.rb`).
- **Assets** :
  - JS applicatif : `app/javascript/**/*`
  - Shakapacker : `bin/shakapacker`, `bin/shakapacker-dev-server`
  - Styles : Tailwind + DaisyUI.
- **Template / schémas** : la logique de builder est exposée via des endpoints, puis exécutée côté navigateur (Vue/JS dans `app/javascript/template_builder`).

## 3) Découpage principal (responsabilités)

### 3.1 Routing
Les endpoints HTTP sont définis dans `config/routes.rb`.
On retrouve clairement plusieurs domaines :
- **UI** : dashboard, templates, submissions, start/submit form, pages publiques.
- **API JSON** : namespace `api` (ressources templates, submitters, submissions, tools, etc.).
- **Webhooks** : endpoints de consultation/paramétrage (dans `/settings/...`).
- **Embedded signing / builder** : routes `js/:filename` et autres endpoints pour l'intégration.

### 3.2 Contrôleurs (HTTP => orchestration)
Chaque page ou endpoint est porté par un contrôleur dans `app/controllers`, typiquement :
- `ApplicationController` : filtre commun (locale, auth, CSP, gestion compte courant).
- `DashboardController` / `TemplatesDashboardController` : liste et parcours admin.
- `TemplatesController` : CRUD des templates et déclenchement reindex + webhooks.
- `StartFormController` : page "publique" de démarrage (création/association du submitter, gestion 2FA si activé).
- `SubmitFormController` : page de soumission (vérification 2FA, update des valeurs, fin / redirections).
- `TemplatesDetectFieldsController` / `TemplatesPreviewController` etc. : endpoints pour la partie builder (détection/changements/preview).

Exemples de points clés :
- `StartFormController` utilise la création d'un `Submitter`, puis :
  - `WebhookUrls.enqueue_events(...)`
  - `SearchEntries.enqueue_reindex(...)`
  - et déclenche des jobs d'expiration.
- `SubmitFormController#update` appelle `Submitters::SubmitValues.call(...)` puis renvoie `200` ou des erreurs JSON.

### 3.3 Couches métier (service objects dans `lib/`)
La logique métier n'est pas uniquement dans les modèles : on trouve aussi des objets de service et utilitaires dans `lib/` :
- intégration et envoi de webhooks,
- génération/traitement des pièces jointes,
- outils d'export et de génération d'audit trail,
- constantes produit / URLs (via `lib/docuseal.rb`).

### 3.4 Jobs Sidekiq
Les traitements asynchrones sont dans `app/jobs/` et envoyés depuis les contrôleurs/services.
On voit par exemple des jobs du type :
- `send_*_webhook_request_job.rb`
- `process_submitter_completion_job.rb`
- `reindex_all_search_entries_job.rb`

Sidekiq est démarré via `lib/puma/plugin/sidekiq_embed.rb` et utilise la config `config/sidekiq.yml`.

### 3.5 Front-end (Vue/JS + Turbo)
- Builder de formulaires : `app/javascript/template_builder/**/*` (Vue composants).
- Form signing UI : `app/javascript/submission_form/**/*`.
- Le thème UI (DaisyUI) se règle via `data-theme` dans les layouts + la config Tailwind.

### 3.6 Multi-tenancy et configuration
Le mode `MULTITENANT=true` change des routes (ex : legacy ActiveStorage routes) et des comportements produit dans `config/routes.rb` / `lib/docuseal.rb`.

## 4) Flux fonctionnels (end-to-end)

### 4.1 Création d'un template (builder)
1. L'utilisateur admin crée/édite un template (`TemplatesController`).
2. Les schémas de documents et les champs sont maintenus dans le modèle `Template` (via `schema_documents` et paramètres structurés).
3. Des actions "builder" (preview, detect fields, clone & replace, etc.) s'exécutent via des endpoints dédiés.

Résultat : un template est "fillable/signable" et prêt pour recevoir des submissions.

### 4.2 Démarrage d'un formulaire (start form)
Endpoint public (ex : `/d/...`) géré par `StartFormController`.
1. Chargement du template par `slug` (`load_template`).
2. Création / chargement du `Submitter` lié (gestion du cas "shared link").
3. Vérification des exigences (expiré/archivé, champs obligatoires, 2FA si activé).
4. Enregistrement du submitter et création de la `Submission` si besoin.
5. Déclenchement des événements (webhooks, reindex recherche, expiration).

### 4.3 Remplissage / signature (submit form)
Le formulaire de soumission (ex : `/s/...`) est orchestré par `SubmitFormController`.
1. `show` précharge les pages/attachments, gère le cas 2FA et la progression.
2. `update` reçoit les valeurs (PUT JSON/param) et les applique via `Submitters::SubmitValues`.
3. La complétion finale déclenche les jobs et webhooks correspondants.

### 4.4 Webhooks & API
- Les endpoints API JSON sont groupés sous `namespace :api`.
- Les webhooks sont déclenchés par des events (création template/submission, complétion, etc.) via des jobs Sidekiq.

## 5) Fonctionnalités (liste)
D'après `README.md` et les routes/contrôleurs présents :
- Création de formulaires PDF (builder WYSIWYG) avec types de champs (signature, date, checkbox, file, etc.).
- Plusieurs submitters par document / logique d'ordre de signature.
- Pages publiques de start form (liens partagés) + gestion d'invitation/verification.
- Soumission de formulaire (fill + signature) sur mobile (optimisation UI).
- Signature électronique automatique (selon config du serveur) + vérification.
- Stockage de fichiers via disque ou S3 / Google Cloud / Azure (selon config).
- Emails automatiques via SMTP.
- Gestion des utilisateurs et autorisations (dashboard admin, rôles, settings).
- API et webhooks pour intégrations externes.
- Paramètres avancés :
  - stockage,
  - recherche & reindex,
  - notifications,
  - SMS,
  - intégrations (ex : API/MCP),
  - SSO/SAML,
  - personnalisation (logo/couleurs/policies côté UI).
- Multi-tenancy (selon `MULTITENANT`) avec variations de routes.
- Support d'embedded signing / embedded builder (scripts et composants front).

## 6) Déploiement / Exécution (commandes)

### 6.1 Via Docker Compose (recommandé)
1. Définir le host (pour Caddy) :
   - `export HOST=your-domain-name.com`
2. Lancer l'infra (app + postgres + caddy) :
   - `sudo HOST=$HOST docker compose up -d`
3. Exécuter les migrations / préparation DB :
   - `docker compose exec app bin/rails db:prepare`

Notes :
- La config `docker-compose.yml` démarre un PostgreSQL (et Caddy en reverse proxy).
- Le conteneur `app` exécute Puma en production ; les jobs Sidekiq sont démarrés embarqués via plugins Puma.

### 6.2 Exécution Rails en direct (sans Docker)
1. Installer dépendances :
   - `bundle install`
   - `yarn install`
2. Préparer la base de données :
   - `bin/rails db:prepare`
3. Démarrer le serveur :
   - `bin/rails server -b 0.0.0.0 -p 3000`
   - ou `bundle exec puma -C config/puma.rb --dir .`

### 6.3 Script de setup (dev/local)
- Le script `bin/setup` exécute typiquement :
  - `bundle install` (si besoin),
  - `bin/rails db:prepare`,
  - nettoyage de logs/tmp,
  - redémarrage serveur.

