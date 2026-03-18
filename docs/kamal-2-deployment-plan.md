# Kamal 2 Dockerized Deployment Plan

Last reviewed: March 15, 2026

Update: the repo is now scaffolded for a single-host Kamal deployment that runs PostgreSQL and Redis as Docker accessories on the same host as the app. This is a pragmatic baseline for the current DigitalOcean droplet setup, even though managed data services are still the longer-term recommendation for higher durability.

## Goal

Deploy the Rails backend with Kamal 2 using the existing Docker image flow, with a clean path for staging and production, zero-downtime app deploys, and explicit handling for PostgreSQL, Redis, and secrets.

## Current repo assessment

- The backend already has a production-oriented Dockerfile in [backend/Dockerfile](/Users/luunguyen/Code/personal/Respite/backend/Dockerfile).
- The image currently exposes port `80` and starts through Thruster, which matches Kamal 2's default assumption that the app listens on port `80`.
- The app already exposes `GET /up` through Rails health routes, which lines up with Kamal proxy health checks.
- Production currently depends on runtime env vars for:
  - `DATABASE_URL`
  - `REDIS_URL`
  - `CREEM_API_KEY`
  - `CREEM_WEBHOOK_SECRET`
  - `CREEM_SUCCESS_URL`
  - `CREEM_CANCEL_URL`
  - `SUPPORT_API_KEY`
  - `CLAIM_LINK_BASE_URL`
  - `ALLOWED_ORIGINS`
  - `ACTIVE_RECORD_ENCRYPTION_*`
  - `MAILER_HOST`
  - `FORCE_SSL`
- Risk: [backend/config/master.key](/Users/luunguyen/Code/personal/Respite/backend/config/master.key) is currently present in the repo even though [backend/.gitignore](/Users/luunguyen/Code/personal/Respite/backend/.gitignore) ignores `config/*.key`. This should be treated as a leaked secret and rotated before production deployment.

## Research-backed deployment decisions

### 1. Use Kamal 2 with the app's Dockerfile, not buildpacks

This backend already has the right shape for Kamal: a production Dockerfile, port `80`, and `/up`.

### 2. Prefer native Kamal in CI/admin environments; allow Dockerized Kamal only as a fallback

Official Kamal docs support running Kamal via Docker, but call out limitations:

- secrets helper CLIs are unavailable in the container
- host env vars are not automatically injected
- only SSH agent forwarding is available by default

Recommendation:

- Primary path: install Kamal as a Ruby gem in CI or the deployment runner.
- Fallback path: support the Dockerized Kamal alias for local/manual deploys only.

### 3. Use managed PostgreSQL in production; Redis can be managed or an accessory

Kamal accessories are explicitly managed separately from the main service and do not get zero-downtime updates. That makes them a weaker fit for the primary production database.

Recommendation:

- Production PostgreSQL: managed service.
- Production Redis: managed service preferred; accessory acceptable for early-stage/low-risk usage.
- Staging PostgreSQL/Redis: Kamal accessories are acceptable if cost/simplicity matters more than durability.

This recommendation is an inference from Kamal's accessory model plus the backend's need for durable purchase/license data.

### 4. Use Kamal proxy with HTTPS and explicit health checks

Kamal 2 uses `kamal-proxy`, not Traefik. It provides gapless deploys and checks app readiness through the configured app port and health path. Since this app already serves `/up` and listens on `80`, it fits the default model well.

### 5. Use destinations from day one

Kamal merges `config/deploy.yml` with destination-specific files such as `config/deploy.staging.yml`. This is the right way to separate staging and production hosts, secrets, and domains.

### 6. Build for the server architecture explicitly

Kamal 2 requires `builder.arch`. Because this team is on Apple Silicon locally and many deployment targets are `amd64`, we should set the target architecture explicitly and choose either:

- single-arch `amd64` builds
- multi-arch builds if both `amd64` and `arm64` servers are expected

If deploys happen from Apple Silicon to `amd64` servers, a remote builder is worth planning early to avoid slow emulated builds.

## Recommended target architecture

### Environment layout

- `staging`
  - 1 app host
  - PostgreSQL accessory or managed Postgres
  - Redis accessory or managed Redis
  - single domain like `api-staging.respite.app`

- `production`
  - 2+ web hosts behind DNS/load balancing
  - managed PostgreSQL
  - managed Redis
  - domain like `api.respite.app`

### Registry

Use a private registry supported well by Kamal, such as:

- GHCR if GitHub is already central to release workflows
- Docker Hub private repo if simplicity matters
- ECR if production will live on AWS

Recommendation: GHCR unless infrastructure is already AWS-first.

### Deployment runner

- CI job or dedicated admin machine installs `kamal` via Ruby.
- Local developers may use a Dockerized `kamal` alias for manual staging operations if needed.

## Implementation plan

### Phase 0: Prerequisites and decisions

1. Choose hosting targets for staging and production.
2. Choose container registry.
3. Decide PostgreSQL/Redis strategy per environment.
4. Decide whether deploys run from CI, a shared admin machine, or both.
5. Rotate `config/master.key` and any credentials derived from it.

Exit criteria:

- infra owner assigned
- domains assigned
- registry chosen
- secret rotation completed

### Phase 1: Container and app hardening

1. Review the generated Dockerfile for production deploy behavior.
2. Decide whether to keep Thruster or switch to Puma directly.
   - Keep Thruster if you want Kamal default port `80` with a simple front door.
   - Switch to Puma if you want fewer moving parts and are fine setting `proxy.app_port: 3000`.
3. Confirm the container boots with production env vars only.
4. Add any missing production-only env defaults explicitly.
5. Confirm `GET /up` remains lightweight and does not depend on external vendors.

Exit criteria:

- image builds reproducibly
- container boots locally with production env vars
- `/up` responds quickly

### Phase 2: Kamal config scaffold

Create:

- `backend/config/deploy.yml`
- `backend/config/deploy.staging.yml`
- `backend/config/deploy.production.yml`
- `backend/.kamal/secrets-common.example`
- `backend/.kamal/secrets.staging.example`
- `backend/.kamal/secrets.production.example`

Base `deploy.yml` should define:

- `service`
- `image`
- `minimum_version`
- `registry`
- `builder`
- `env.clear`
- `env.secret`
- `proxy`
- `aliases`
- `ssh`
- `boot`
- `deploy_timeout`
- `drain_timeout`
- `retain_containers`

Recommended initial values:

- `minimum_version: 2.10.0`
- `builder.arch: amd64`
- `deploy_timeout: 60`
- `drain_timeout: 30`
- `retain_containers: 5`
- `boot.limit: 1` for first production rollout, then relax later

Exit criteria:

- `kamal config -d staging` passes
- `kamal config -d production` passes

### Phase 3: Secrets model

Move deployment/runtime secrets into Kamal 2's `.kamal/secrets` model.

Secrets to include:

- `KAMAL_REGISTRY_PASSWORD`
- `RAILS_MASTER_KEY`
- `DATABASE_URL`
- `REDIS_URL`
- `CREEM_API_KEY`
- `CREEM_WEBHOOK_SECRET`
- `SUPPORT_API_KEY`
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`
- optional certificate secrets if using custom TLS certs

Clear env values likely safe to keep in config:

- `RAILS_LOG_LEVEL`
- `FORCE_SSL`
- `MAILER_HOST`
- `CREEM_SUCCESS_URL`
- `CREEM_CANCEL_URL`
- `CLAIM_LINK_BASE_URL`
- `ALLOWED_ORIGINS`

If Dockerized Kamal is used locally, document the extra env injection required for registry auth and any secret-manager integration gaps.

Exit criteria:

- no runtime secrets are stored in Git
- rotated Rails master key is only delivered through Kamal secrets

### Phase 4: Data services

#### Preferred production path

1. Provision managed PostgreSQL.
2. Provision managed Redis.
3. Add network/firewall rules so only app hosts can connect.
4. Store connection URLs in Kamal secrets.

#### Acceptable staging path

1. Define PostgreSQL and Redis as Kamal accessories.
2. Mount persistent directories/volumes.
3. Bind ports to localhost/private network only.
4. Add backup procedure for Postgres accessory if staging data matters.

Exit criteria:

- app can boot in each environment with its real data services

### Phase 5: Deployment workflow

1. Run `kamal setup -d staging`.
2. Run database preparation against the staging app image:
   - `kamal app exec -d staging --primary --reuse "bin/rails db:prepare"`
3. Validate app health and webhook endpoints.
4. Repeat for production once staging is stable.

Recommended aliases to add:

- `console: app exec -i --reuse "bin/rails console"`
- `logs: app logs -f`
- `dbprepare: app exec --primary --reuse "bin/rails db:prepare"`
- `migrate: app exec --primary --reuse "bin/rails db:migrate"`
- `shell: app exec -i --reuse "bash"`

For production deploys:

1. Build and push image via `kamal deploy -d production`
2. Run `kamal migrate -d production` if you define that alias or equivalent command
3. Verify `/up`
4. Verify one real API endpoint, such as a read-only status endpoint

Exit criteria:

- staging deploy succeeds end to end
- production deploy succeeds with no downtime

### Phase 6: Operational hardening

1. Add hooks for pre-build and post-deploy notifications.
2. Add rollback runbook using `kamal rollback`.
3. Add restore runbook for database backups.
4. Add DNS/TLS runbook.
5. Add deploy ownership and approval policy.
6. Add monitoring:
   - uptime checks on `/up`
   - app logs
   - host disk usage
   - database health
   - Redis health

Exit criteria:

- documented rollback
- documented secret rotation
- documented incident owner

## Concrete action items

### High priority

- Rotate and remove the tracked Rails master key from the repo history and active credentials set.
- Decide production data service strategy: managed Postgres/Redis vs accessories.
- Choose registry and image naming convention.
- Add Kamal config files for base, staging, and production.
- Add `.kamal/secrets*.example` templates.
- Validate image boot with production env vars.

### Medium priority

- Add Kamal aliases for console, logs, db prepare, migrate, and shell.
- Add staging domain and TLS setup.
- Add pre-build and post-deploy hooks.
- Decide whether to keep Thruster or simplify to Puma-only.
- Add remote builder if deploys will originate from Apple Silicon to `amd64`.

### Lower priority

- Add a separate worker role later if background jobs are introduced.
- Add proxy buffering/logging tuning once traffic shape is known.
- Add a Dockerized Kamal wrapper script for local operators if needed.

## Suggested first implementation slice

If we want the smallest safe slice, do this first:

1. Rotate `RAILS_MASTER_KEY` and stop tracking `config/master.key`.
2. Provision staging host, staging Postgres, staging Redis.
3. Add `config/deploy.yml` and `config/deploy.staging.yml`.
4. Add `.kamal/secrets.staging`.
5. Run `kamal config -d staging`.
6. Run `kamal setup -d staging`.
7. Run `kamal app exec -d staging --primary --reuse "bin/rails db:prepare"`.
8. Validate `GET /up`, one Creem-free API path, and logs.
9. Repeat for production only after staging deploy is stable.

## Placeholder targets currently wired in repo

- Registry: `ghcr.io/respite/respite-backend`
- SSH user: `deploy`
- Staging app host: `staging-app-1.respite.internal`
- Staging Postgres host: `staging-db-1.respite.internal`
- Staging Redis host: `staging-cache-1.respite.internal`
- Staging API domain: `api-staging.respite.placeholder.example`
- Production app hosts: `prod-app-1.respite.internal`, `prod-app-2.respite.internal`
- Production Postgres host: `prod-postgres.respite.internal`
- Production Redis host: `prod-redis.respite.internal`
- Production API domain: `api.respite.example`
- Production TLS mode: upstream termination assumed, so Kamal proxy SSL is disabled in production

## Open questions to resolve before implementation

1. Will production run on one host or multiple web hosts?
2. Is registry preference GHCR, Docker Hub, or ECR?
3. Do you want Kamal run from CI, from local machines, or both?
4. Should Redis be treated as disposable cache-only, or do we expect queue/session usage later?
5. Are we comfortable with Let’s Encrypt on a single host, or do we need custom certs / an upstream load balancer?

## Primary sources

- Kamal installation: https://kamal-deploy.org/docs/installation/
- Running Kamal via Docker: https://kamal-deploy.org/docs/installation/dockerized/
- Kamal configuration overview: https://kamal-deploy.org/docs/configuration/overview/
- Kamal environment variables and secrets: https://kamal-deploy.org/docs/configuration/environment-variables/
- Kamal builder config: https://kamal-deploy.org/docs/configuration/builders/
- Kamal builder examples: https://kamal-deploy.org/docs/configuration/builder-examples/
- Kamal proxy config: https://kamal-deploy.org/docs/configuration/proxy/
- Kamal accessories: https://kamal-deploy.org/docs/configuration/accessories/
- Kamal roles: https://kamal-deploy.org/docs/configuration/roles/
- Kamal aliases: https://kamal-deploy.org/docs/configuration/aliases/
- Kamal setup command: https://kamal-deploy.org/docs/commands/setup/
- Kamal deploy command: https://kamal-deploy.org/docs/commands/deploy/
- Kamal app commands: https://kamal-deploy.org/docs/commands/app/
- Kamal hooks overview: https://kamal-deploy.org/docs/hooks/overview/
- Kamal 2 configuration changes: https://kamal-deploy.org/docs/upgrading/configuration-changes/
- Kamal 2 secrets changes: https://kamal-deploy.org/docs/upgrading/secrets-changes/
