# Contributing

## Before you start

```bash
cd backend && pnpm install && cp .dev.vars.example .dev.vars && pnpm db:migrate:local
cd app && flutter pub get
```

`.dev.vars` needs a `JWT_SECRET` of at least 16 characters before `wrangler dev` will serve requests;
the API fails fast with a clear message if it is missing.

## Checks

Everything CI runs, runnable locally:

```bash
cd backend && pnpm typecheck && pnpm lint && pnpm test
cd app && flutter analyze && flutter test
cd design && pnpm exec tsc --noEmit && pnpm build
```

Pull requests are expected to keep all of these green.

## Branches and commits

- Branch off `develop`, name it `feature/<thing>` or `fix/<thing>`, and target `develop`.
- `main` is release history only.
- Write imperative commit subjects, optionally conventional-prefixed:
  `feat: add FCM device registration`, `fix: prevent duplicate notifications`,
  `chore: bump wrangler`.

## Conventions worth knowing

- The backend is the source of truth for birthdays, reminders and notification state.
- The client never sends a user id. Ownership always comes from the bearer token — a route that
  takes an id must filter by the authenticated user.
- Recurring birthdays are month/day plus an optional birth year; 29 February falls back to
  28 February in non-leap years.
- Timestamps are stored in UTC; reminder times are wall-clock in the user's IANA timezone.
- Reminder delivery must stay idempotent. The unique `dedupe_key` on `notification_logs` is what
  makes repeated cron runs safe — do not bypass it.
- Never commit secrets. They live in `.dev.vars` locally and in `wrangler secret` when deployed.
- New behaviour needs a test. Watch for async hydration during build, and for work whose cost only
  shows up on the real platform — Cloudflare caps PBKDF2 at 100,000 iterations, which local `workerd`
  does not enforce.

## Design reference

`design/` is the visual source of truth. If a screen's look changes, change the design surface too so
the two do not drift.
