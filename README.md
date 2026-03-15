# Respite Backend

Rails API for Respite Pro checkout, licensing, claims, webhooks, and support tooling.

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
