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

For the current single-host Dockerized setup, PostgreSQL and Redis run as Kamal accessories and the app connects to them over the shared `kamal` Docker network using the service names `postgres` and `redis`. The example `.kamal/secrets-*` files already reflect that.

## Single Droplet Rollout

For a single Ubuntu 24.04 x64 DigitalOcean droplet, the current production config is IP-first and HTTP-only until you have a real domain. Replace the placeholder IP `192.81.216.87` in [config/deploy.production.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.production.yml) with your droplet IP.

Recommended order:

1. If PostgreSQL already exists, keep it and set `DATABASE_URL` in `.kamal/secrets` to that server.
2. If Redis already exists, keep it and set `REDIS_URL` in `.kamal/secrets` to that server.
3. If PostgreSQL does not exist yet, boot the Kamal accessory:

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal accessory boot postgres -d production
```

4. If Redis does not exist yet, boot the Kamal accessory:

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal accessory boot redis -d production
```

5. Point the app at whichever PostgreSQL and Redis you chose by setting `DATABASE_URL` and `REDIS_URL` in `.kamal/secrets`.
   If you use the bundled accessories on the same droplet, use:

```bash
DATABASE_URL=postgres://respite_backend:${POSTGRES_PASSWORD}@postgres:5432/respite_backend_production
REDIS_URL=redis://redis:6379/0
```

6. Deploy the app:

```bash
RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal setup -d production
RBENV_VERSION=3.4.2 rbenv exec bundle exec kamal app exec -d production --primary --reuse "bin/rails db:prepare"
```

When you later move to a real domain, switch `proxy.host`, `MAILER_HOST`, `CREEM_SUCCESS_URL`, `CREEM_CANCEL_URL`, and `ALLOWED_ORIGINS`, then re-enable SSL and `FORCE_SSL`.

If you prefer Dockerized Kamal instead of the local gem:

```bash
bin/kamal-docker config -d staging
bin/kamal-docker setup -d staging
```

See these docs for deployment details:

- [App integration API](/Users/luunguyen/Code/personal/Respite/backend/docs/app-integration-api.md)
- [DigitalOcean droplet deploy guide](/Users/luunguyen/Code/personal/Respite/backend/docs/digitalocean-droplet-deploy-guide.md)
- [Kamal 2 deployment plan](/Users/luunguyen/Code/personal/Respite/backend/docs/kamal-2-deployment-plan.md)

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
