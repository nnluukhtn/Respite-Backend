# Respite Backend

Rails API for Respite licensing, claims, webhooks, and support tooling.

## Stack

- Ruby `3.4.2`
- Rails `8.1.2`
- PostgreSQL
- Redis

## Setup

1. Copy `.env.example` values into your shell or env manager.
2. Ensure PostgreSQL and Redis are running locally.
3. Install gems:

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle install
```

4. Create and migrate the database:

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle exec rails db:prepare
```

5. Start the API:

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle exec rails server
```

## Test And Lint

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle exec rspec
RBENV_VERSION=3.4.2 rbenv exec bundle exec rubocop
```

## Deploy With Kamal 2

The repo now includes Kamal 2 deployment scaffolding:

- `config/deploy.yml`
- `config/deploy.staging.yml`
- `config/deploy.production.yml`
- `.kamal/secrets-common.example`
- `.kamal/secrets-staging.example`
- `.kamal/secrets-production.example`
- `bin/kamal-docker`

Suggested first-time setup:

```bash
cp .kamal/secrets.example .kamal/secrets
# append values from .kamal/secrets-common.example and the staging or production example as needed

RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal config -d staging
RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal setup -d staging
RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal app exec -d staging --primary --reuse "bin/rails db:prepare"
```

If you prefer Dockerized Kamal instead of the local gem:

```bash
bin/kamal-docker config -d staging
bin/kamal-docker setup -d staging
```

See [docs/kamal-2-deployment-plan.md](/Users/luunguyen/Code/personal/Respite/backend/docs/kamal-2-deployment-plan.md) for the rollout plan and environment decisions still needing real infra values.

## Main Endpoints

- `POST /api/pro/checkout_sessions`
- `POST /api/pro/webhooks/creem`
- `POST /api/pro/claims/redeem`
- `POST /api/pro/licenses/activate`
- `GET /api/pro/licenses/status`
- `POST /api/pro/licenses/deactivate`
- `GET /api/support/licenses/:reference`
- `GET /api/support/licenses/:reference/activations`
- `POST /api/support/licenses/:reference/release`
- `POST /api/support/licenses/:reference/resend_claim_link`
- `POST /api/support/purchases/resync`

## Notes

- License keys are stored with Active Record encryption and a separate digest for lookup.
- Claim tokens are one-time, short-lived, and intended for the app return flow.
- Webhook events are stored idempotently in `vendor_webhook_events`.
- Variant mapping lives in `config/license_variants.yml`.
- Product tiers are currently `pro` (1 seat), `ultimate` (3 seats), and `enterprise` (custom seats per company).
