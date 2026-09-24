# Deployment runbook

This runbook takes the backend to Cloudflare and produces a signed Android release. Every name and
identifier below is a placeholder — substitute your own account's values before you deploy.

## Resources you need

| Resource | Staging | Production |
| --- | --- | --- |
| Worker | `birthday-reminder-staging` | `birthday-reminder` |
| Public URL | `https://birthday-reminder-staging.YOUR-SUBDOMAIN.workers.dev` | `https://birthday-reminder.YOUR-SUBDOMAIN.workers.dev` |
| D1 database | `birthday-reminder-staging` | `birthday-reminder` |
| R2 bucket | `birthday-reminder-photos-staging` | `birthday-reminder-photos` |
| Cron trigger | `* * * * *` | `* * * * *` |
| Secrets | `JWT_SECRET`, `FCM_SERVICE_ACCOUNT` | `JWT_SECRET`, `FCM_SERVICE_ACCOUNT` |

Named environments do not inherit bindings, vars or triggers, so `backend/wrangler.jsonc` repeats
them inside each `env` block. Replace the placeholder D1 database ids and `APP_BASE_URL` values there
with your own before the first deploy.

## First-time setup

```bash
cd backend
pnpm exec wrangler login

# Create the storage, then copy each database id into wrangler.jsonc.
pnpm exec wrangler d1 create birthday-reminder-staging
pnpm exec wrangler d1 create birthday-reminder
pnpm exec wrangler r2 bucket create birthday-reminder-photos-staging
pnpm exec wrangler r2 bucket create birthday-reminder-photos

# Apply the schema to each database.
pnpm exec wrangler d1 migrations apply birthday-reminder-staging --env staging --remote
pnpm exec wrangler d1 migrations apply birthday-reminder --env production --remote
```

R2 has to be enabled on the account before bucket creation works, otherwise the API answers with
Cloudflare error `10042`.

## Everyday commands

```bash
cd backend
pnpm exec wrangler deploy --env staging          # deploy staging
pnpm exec wrangler deploy --env production       # deploy production
pnpm exec wrangler tail --env staging            # live logs, including cron runs
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
| `FCM_SERVICE_ACCOUNT` | Firebase service-account JSON, on a single line. The same Firebase project can serve both environments |
| `RESEND_API_KEY`, `EMAIL_FROM` | Optional. Without them, password-reset emails are logged instead of sent |

## Updating the app for an environment

The API origin is a compile-time value:

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://YOUR_WORKER_URL \
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

Create an upload keystore (once per project) and point `app/android/key.properties` at it:

```bash
keytool -genkeypair -v -keystore app/android/upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

```properties
# app/android/key.properties — gitignored, never commit it
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

`build.gradle.kts` reads that file when it exists and falls back to the debug keys when it is
missing, so contributors can still build without the keystore.

> **Back this keystore up somewhere safe.** If it is lost you cannot ship updates under the same
> identity unless Play App Signing is enabled and you reset the upload key. It is not in git.

Build the release bundle and confirm the signer before uploading:

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://YOUR_WORKER_URL \
  --dart-define=APP_VERSION=1.0.0

keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

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
