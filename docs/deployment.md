# Deployment runbook

Staging is deployed and verified. Production is prepared but not deployed.

## Current resources

| | staging | production |
| --- | --- | --- |
| Worker | `birthday-reminder-staging` | `birthday-reminder` (not deployed) |
| URL | https://birthday-reminder-staging.jpaypay17.workers.dev | https://birthday-reminder.jpaypay17.workers.dev |
| D1 | `birthday-reminder-staging` (`287fb6d2-02a9-4c0e-8bcf-ce9464e6fdc9`) | `birthday-reminder` (`12220dcc-c1bd-441b-bf8c-fec98e1a951e`) |
| R2 | `birthday-reminder-photos-staging` | `birthday-reminder-photos` |
| Cron | `* * * * *` | `* * * * *` |
| Secrets | `JWT_SECRET`, `FCM_SERVICE_ACCOUNT` | `JWT_SECRET`, `FCM_SERVICE_ACCOUNT` |

Both environments are defined in `backend/wrangler.jsonc` under `env`. Named environments do not
inherit bindings, vars or triggers, so each block repeats them.

## Everyday commands

```bash
cd backend
pnpm exec wrangler deploy --env staging          # deploy staging
pnpm exec wrangler deploy --env production       # deploy production (once approved)
pnpm exec wrangler tail --env staging            # live logs, includes cron runs
pnpm exec wrangler d1 migrations apply birthday-reminder-staging --env staging --remote
pnpm exec wrangler secret list --env staging     # names only, never values
```

## Secrets

Secrets are per environment and are never committed. `.dev.vars` only covers local development.

```bash
# Pipe a value in to avoid putting it in your shell history:
printf '%s' '<value>' | pnpm exec wrangler secret put JWT_SECRET --env staging
```

| Secret | Notes |
| --- | --- |
| `JWT_SECRET` | Signs 30-day access tokens. Generate a fresh one per environment — staging and production must not share it |
| `FCM_SERVICE_ACCOUNT` | Firebase service-account JSON, single line. Same Firebase project for both environments is fine |
| `RESEND_API_KEY`, `EMAIL_FROM` | Optional. Without them, password-reset emails are logged instead of sent |

## Updating the app for an environment

The API origin is a compile-time value:

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://birthday-reminder-staging.jpaypay17.workers.dev \
  --dart-define=APP_VERSION=1.0.0
```

Debug builds allow cleartext HTTP so they can also point at a local Worker; release builds refuse it,
so release builds must use an `https://` origin.

## Platform limits that only appear in production

These behave differently on Cloudflare than in local `workerd`, so they are worth remembering:

- **PBKDF2 iteration cap**: the runtime rejects anything above 100,000 ("iteration counts above 100000
  are not supported"). Local `workerd` does not enforce it, so a higher value passes every test and
  fails every real signup. `backend/src/lib/crypto.ts` is pinned to the cap and a test guards it.
- **R2 must be enabled on the account** before `wrangler r2 bucket create` works; otherwise the API
  answers `code 10042`.
- **Cron triggers are not inherited** by named environments — repeat `triggers` in each `env` block.
- **Each D1 database needs its own migration run** per environment.

## Android release signing

Release builds currently fall back to debug keys, which Play rejects. Create an upload keystore and
point the build at it:

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then create `app/android/key.properties`:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/upload-keystore.jks
```

`app/android/app/build.gradle.kts` reads that file when present and keeps using debug keys when it is
absent, so contributors can still build without the keystore.

## Verifying a deployment

1. `curl https://<worker-host>/health` returns `{ "status": "ok", "environment": "staging" }`.
2. Register, sign in, add a birthday with a reminder, and confirm it appears on Home and Calendar.
3. Upload a photo and read it back: `POST /api/photos` then `GET` the returned URL with the same token.
4. Send a test notification from the app and confirm the tray notification (leave the app first).
5. Confirm the cron engine is running: `wrangler tail --env staging` shows
   `reminder_engine_run { … }` every minute, and a due reminder writes a `notification_logs` row.

## Rollback

- Worker: `wrangler deployments list --env staging` then `wrangler rollback [deployment-id] --env staging`.
- D1: migrations are forward-only; restore with Time Travel
  (`wrangler d1 time-travel restore <db> --bookmark <id>`) and redeploy the previous Worker version.
- Android: halt the Play release and re-promote the previous bundle.
