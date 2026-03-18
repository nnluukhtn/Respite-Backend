# DigitalOcean Droplet Deploy Guide

This guide is for the current production shape:

- Ubuntu 24.04 x64 DigitalOcean droplet
- app deployed with `bundle exec kamal`
- PostgreSQL and Redis running either:
  - as Kamal Docker accessories on the same droplet, or
  - as existing services you already have
- app currently served by IP first, domain later

Current production host in the repo:

- `192.81.216.87`

Current production config lives in:

- [config/deploy.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.yml)
- [config/deploy.production.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.production.yml)
- [.kamal/secrets](/Users/luunguyen/Code/personal/Respite/backend/.kamal/secrets)

## 1. Preflight

Before the first deploy, make sure:

- your droplet is reachable over SSH
- port `80` is open on the droplet firewall
- Docker can be installed or is already installed
- the SSH user in [config/deploy.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.yml) is correct
  - the repo currently uses `deploy`
- your container registry token is valid
- [`.kamal/secrets`](/Users/luunguyen/Code/personal/Respite/backend/.kamal/secrets) is present locally

## 2. Required Secrets

Your local [`.kamal/secrets`](/Users/luunguyen/Code/personal/Respite/backend/.kamal/secrets) should include:

```bash
KAMAL_REGISTRY_PASSWORD=...
RAILS_MASTER_KEY=...

POSTGRES_PASSWORD=...
DATABASE_URL=postgres://respite_backend:${POSTGRES_PASSWORD}@postgres:5432/respite_backend_production
REDIS_URL=redis://redis:6379/0

CREEM_API_KEY=...
CREEM_WEBHOOK_SECRET=...
SUPPORT_API_KEY=...

ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

If you are reusing an existing PostgreSQL or Redis instead of Kamal accessories:

- keep `POSTGRES_PASSWORD` only if you still want the bundled Postgres accessory config available
- set `DATABASE_URL` to your existing PostgreSQL server
- set `REDIS_URL` to your existing Redis server

Example:

```bash
DATABASE_URL=postgres://USER:PASSWORD@YOUR_DB_HOST:5432/respite_backend_production
REDIS_URL=redis://YOUR_REDIS_HOST:6379/0
```

## 3. Choose Your Data Service Path

### Option A: Use existing PostgreSQL and Redis

Use this if you already provisioned them yourself.

What to do:

- update `DATABASE_URL` in [`.kamal/secrets`](/Users/luunguyen/Code/personal/Respite/backend/.kamal/secrets)
- update `REDIS_URL` in [`.kamal/secrets`](/Users/luunguyen/Code/personal/Respite/backend/.kamal/secrets)
- skip the accessory boot commands below

### Option B: Use Kamal-managed PostgreSQL and Redis on the droplet

Use this if you want the simplest single-box setup.

The repo is already configured for this in [config/deploy.production.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.production.yml).

In this mode, the app connects to:

- `postgres` on port `5432`
- `redis` on port `6379`

over the shared `kamal` Docker network.

## 4. Validate Local Config

From the backend directory:

```bash
cd /Users/luunguyen/Code/personal/Respite/backend
bundle exec kamal config -d production
bundle exec kamal registry login -d production
```

If `kamal registry login` fails:

- re-check `KAMAL_REGISTRY_PASSWORD`
- re-check the registry path in [config/deploy.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.yml)

## 5. First-Time Deploy

### If PostgreSQL is not set up yet

Boot the Postgres accessory:

```bash
bundle exec kamal accessory boot postgres -d production
```

### If Redis is not set up yet

Boot the Redis accessory:

```bash
bundle exec kamal accessory boot redis -d production
```

### Deploy the app

Run initial Kamal setup:

```bash
bundle exec kamal setup -d production
```

Then prepare the database:

```bash
bundle exec kamal app exec -d production --primary --reuse "bin/rails db:prepare"
```

## 6. Verify The Deployment

Health check:

```bash
curl http://192.81.216.87/up
```

View app logs:

```bash
bundle exec kamal app logs -d production
```

Open a shell in the app container:

```bash
bundle exec kamal shell -d production
```

Open a Rails console:

```bash
bundle exec kamal console -d production
```

## 7. Normal Future Deploys

After the first setup, normal deploys are:

```bash
bundle exec kamal deploy -d production
```

If you changed schema:

```bash
bundle exec kamal app exec -d production --primary --reuse "bin/rails db:migrate"
```

## 8. Current IP-First Notes

The repo is currently configured for direct IP access in [config/deploy.production.yml](/Users/luunguyen/Code/personal/Respite/backend/config/deploy.production.yml):

- `proxy.host: 192.81.216.87`
- `ssl: false`
- `FORCE_SSL: false`

This is intentional for now.

When you later add a real domain, update:

- `proxy.host`
- `MAILER_HOST`
- `CREEM_SUCCESS_URL`
- `CREEM_CANCEL_URL`
- `ALLOWED_ORIGINS`

Then switch:

- `ssl: true`
- `FORCE_SSL: true`

## 9. Important Follow-Ups

- Replace placeholder or temporary URLs with real frontend/app URLs.
- Rotate [config/master.key](/Users/luunguyen/Code/personal/Respite/backend/config/master.key) before long-term production use.
- Replace the placeholder Enterprise Creem product id in [config/license_variants.yml](/Users/luunguyen/Code/personal/Respite/backend/config/license_variants.yml) if it is not your final real value.
- Confirm the SSH user is correct for the droplet.

## 10. Quick Command List

```bash
cd /Users/luunguyen/Code/personal/Respite/backend

bundle exec kamal config -d production
bundle exec kamal registry login

bundle exec kamal accessory boot postgres -d production
bundle exec kamal accessory boot redis -d production

bundle exec kamal setup -d production
bundle exec kamal app exec -d production --primary --reuse "bin/rails db:prepare"

bundle exec kamal deploy -d production
bundle exec kamal app logs -d production
```
