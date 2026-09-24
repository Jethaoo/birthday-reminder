# Deployment runbook

Implementation stops at verified local + staging. This runbook is what you execute to reach
production. Every step is idempotent and can be repeated.

## 1. Prerequisites

- Cloudflare account with Workers, D1 and R2 enabled
- Firebase project (Blaze plan, since FCM HTTP v1 requires it) with an Android app registered as
  `com.birthdayreminder.app`
- Resend account with a verified sending domain
- Android signing keystore for the release build

## 2. Backend secrets

```bash
cd backend
cp .dev.vars.example .dev.vars
```

Fill in:

| Secret | Purpose |
| --- | --- |
| `JWT_SECRET` | HS256 signing key — generate with `openssl rand -base64 48` |
| `FCM_SERVICE_ACCOUNT` | Firebase service-account JSON (single line) used for FCM HTTP v1 |
| `RESEND_API_KEY` | Password-reset email delivery |
| `EMAIL_FROM` | Verified sender, e.g. `Birthday Reminder <noreply@example.com>` |

Never commit `.dev.vars`. For deployed environments use:

```bash
wrangler secret put JWT_SECRET
wrangler secret put FCM_SERVICE_ACCOUNT
wrangler secret put RESEND_API_KEY
wrangler secret put EMAIL_FROM
```

## 3. Resources

```bash
wrangler d1 create birthday-reminder
wrangler r2 bucket create birthday-reminder-photos
wrangler r2 bucket create birthday-reminder-photos-staging
```

Copy the returned D1 `database_id` into `wrangler.jsonc` (`d1_databases[0].database_id`) for each
environment. Keep separate D1 databases and R2 buckets for staging and production.

## 4. Migrations

```bash
pnpm db:migrate:local     # local dev database
pnpm db:migrate:remote    # staging/production (confirm the target first)
```

Migrations live in `backend/migrations` and are applied in filename order.

## 5. Environments

| Environment | `ENVIRONMENT` | Notes |
| --- | --- | --- |
| development | `development` | `wrangler dev`, local D1 and R2, `/api/dev/test-notification` enabled |
| staging | `staging` | Real D1/R2, test notification endpoint enabled, test Firebase project allowed |
| production | `production` | Test notification endpoint returns 404, real FCM and email credentials |

Set the environment with `vars` in `wrangler.jsonc` per deployment, or with
`wrangler deploy --var ENVIRONMENT:production`.

## 6. Deploy the Worker

```bash
cd backend
pnpm test && pnpm typecheck && pnpm lint
wrangler deploy
```

Verify: `curl https://<worker-host>/health` returns `{ "status": "ok" }`.

The cron trigger (`* * * * *`) is created by `wrangler.jsonc`; confirm it under Workers → Triggers
after the first deploy.

## 7. Android app

1. Put the Firebase config at `app/android/app/google-services.json`. The Gradle plugin is applied
   automatically when the file exists, so contributors without it can still build.
2. Point the app at the deployed API:

   ```bash
   flutter build appbundle --release \
     --dart-define=API_BASE_URL=https://<worker-host> \
     --dart-define=APP_VERSION=1.0.0
   ```

3. Create `app/android/key.properties`:

   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=…
   storeFile=/absolute/path/upload-keystore.jks
   ```

   Then switch `signingConfig` in `app/android/app/build.gradle.kts` from the debug keys to a release
   config that reads those values.
4. Upload the resulting `.aab` to Play Console (internal testing → closed → production).

## 8. Post-deploy checks

```bash
# Register, then fetch the dashboard
curl -X POST https://<worker-host>/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test","email":"test@example.com","password":"Password123","confirmPassword":"Password123","timezone":"Asia/Kuala_Lumpur"}'
```

Then on a signed-in device: save a birthday, confirm it appears on Home and Calendar, use
"Send a test notification" (staging only), and confirm the notification tap opens the right birthday.

## 9. Rollback

- Worker: `wrangler deployments list` then `wrangler rollback [deployment-id]`.
- D1: migrations are forward-only; restore from a Time Travel bookmark
  (`wrangler d1 time-travel restore <db> --bookmark <id>`) and redeploy the previous Worker version.
- Android: halt the Play release and re-promote the previous bundle.
