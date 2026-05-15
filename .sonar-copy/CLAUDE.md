# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AFB Document Signing — a fork of DocuSeal (open-source document signing). Rails monolith with Hotwire/Turbo views, a Vue.js form builder, Sidekiq for async processing, and an AFB-specific RBAC layer added on top of upstream.

## Stack

- Ruby `4.0.1` (see `Gemfile`), Rails
- Front-end: ERB views + Hotwire/Turbo, Vue 3 components, Tailwind + DaisyUI, bundled via Shakapacker (Webpack)
- DB: SQLite in dev, PostgreSQL in prod (`docker-compose.yml`)
- Async: Sidekiq, embedded into Puma via `lib/puma/plugin/sidekiq_embed.rb` (config `config/sidekiq.yml`)
- Auth: Devise + `devise-two-factor`; authorization via CanCanCan
- PDF: `hexapdf` + libpdfium (RSpec CI installs `libpdfium.so` from `docusealco/pdfium-binaries`)
- Image processing: `ruby-vips` (libvips system dep)
- Document conversion in production: Gotenberg service (see `docker-compose.yml`)

## Common commands

Local dev (without Docker):
```sh
bin/setup                    # bundle install + db setup
foreman start -f Procfile.dev   # web on :3009 + shakapacker-dev-server
```

Docker (full stack with postgres/redis/gotenberg/caddy):
```sh
docker compose up -d         # do NOT use --no-deps (app needs postgres/redis on the compose network)
sudo HOST=your-domain.com docker compose up    # production-style with Caddy TLS
```

Tests (RSpec):
```sh
bundle exec rspec                        # full suite
bundle exec rspec spec/models/user_spec.rb       # single file
bundle exec rspec spec/models/user_spec.rb:42    # single example by line
COVERAGE=true bundle exec rspec          # generates coverage/lcov.info for SonarQube
```

Linters (all run in CI — `.github/workflows/ci.yml`):
```sh
bundle exec rubocop
bundle exec erb_lint ./app
./node_modules/eslint/bin/eslint.js "app/javascript/**/*.js"
yarn eslint                  # convenience wrapper that auto-fixes JS/Vue
bundle exec brakeman -q --exit-on-warn   # security scan
```

SonarQube scan (config in `sonar-project.properties`, project key `firstSign`, expects local server on `:9000`):
```sh
COVERAGE=true bundle exec rspec    # generate lcov first
sonar-scanner
```

## Architecture

### Controllers
`app/controllers/` is wide and flat — there's one controller per concern (e.g. `submissions_archived_controller.rb`, `submissions_unarchive_controller.rb`, `start_form_email_2fa_send_controller.rb`). When adding behavior, look for an existing single-purpose controller before adding actions to a CRUD one. The JSON API lives under `app/controllers/api/` (mounted at `namespace :api` in `config/routes.rb`).

### Service objects (`lib/`)
Business logic is split between models and `lib/`. Notable namespaces:
- `lib/submitters/`, `lib/submissions/`, `lib/templates/`, `lib/users/` — service objects (e.g. `Submitters::SubmitValues.call(...)` from `SubmitFormController`)
- `lib/abilities/` — CanCan helper conditions (used by `lib/ability.rb`)
- `lib/pdf_utils.rb`, `lib/pdfium.rb`, `lib/hexapdf.rb` initializer — PDF pipeline
- `lib/docuseal.rb` — product constants + `Docuseal.multitenant?` flag that toggles routes/behavior

### RBAC (AFB-specific, not upstream)
`lib/ability.rb` defines a 5-role hierarchy: **admin > editor > member > agent > viewer**. The base `can` rules grant everything; each role then strips back permissions in a `case user.role` block. This means:
- Default rules (top of `initialize`) reflect what an admin can do.
- Lower roles use `cannot ...` to remove access, then `can ...` with scoped conditions (e.g. `created_by_user_id: user.id`) to grant narrow access back.
- Adding a new permission: add it to base rules, then explicitly restrict it for non-admin roles in each case branch.

See `.cursor/rules/rbac.md` and `docs/GUIDE_ROLES_UTILISATEUR.md` for the role spec.

### Frontend
- `app/javascript/template_builder/` — Vue 3 builder (form-field WYSIWYG)
- `app/javascript/submission_form/` — Vue form-filling/signing UI
- `app/javascript/elements/` — custom elements / shared components
- ERB views drive the rest; Turbo handles navigation. Tailwind has multiple configs (`tailwind.application.config.js`, `tailwind.dynamic.config.js`, `tailwind.form.config.js`) for different bundles.

### Multi-tenancy
`Docuseal.multitenant?` (env `MULTITENANT=true`) gates routes and behaviors throughout `config/routes.rb` and `lib/docuseal.rb`. Self-hosted (default) creates a default admin from `DEFAULT_ADMIN_EMAIL` / `DEFAULT_ADMIN_PASSWORD` on first boot.

### Background jobs
`app/jobs/` — fired from controllers and services. Webhooks (`send_*_webhook_request_job.rb`), search reindexing, submission completion processing, etc. Sidekiq UI is mounted at `/jobs` for users with `sidekiq?` permission in non-multitenant mode.

## Conventions

- French is used in some user-facing docs (`docs/GUIDE_*.md`) and in some comments — match the surrounding language when editing.
- Frozen string literals at the top of every Ruby file (enforced by RuboCop).
- `db/schema.rb` and `db/migrate/` are excluded from SonarQube and shouldn't be hand-edited.
- The `docuseal/` and `pg_data/` directories are runtime data volumes — don't commit changes there.
