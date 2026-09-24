# birthday

Monorepo for a production Android birthday reminder app.

## Layout

- `app/` — Flutter application (Dart). Entry point `app/lib/main.dart`.
- `backend/` — Cloudflare Worker (TypeScript) with D1 migrations and the cron reminder engine.
- `design/` — the original Figma Make prototype, extended into the full V1 design surface.
  It is a reference implementation of the visual language, not shipped code. See `design/AGENTS.md`.
- `docs/` — architecture, API reference and deployment runbook.

## Conventions

- The backend is the source of truth for birthdays, reminders and notification state.
- The client never supplies a user id; the authenticated user always comes from the bearer token.
- Recurring birthdays are stored as month/day plus an optional birth year.
- All timestamps are stored in UTC; reminder times are interpreted in the user's IANA timezone.
- 29 February birthdays fall back to 28 February in non-leap years.
- Never commit secrets. Worker secrets live in `.dev.vars` (local) or `wrangler secret` (deployed).

## Commands

```bash
cd backend && pnpm install && pnpm db:migrate:local && pnpm dev
cd backend && pnpm test && pnpm typecheck
cd app && flutter pub get && flutter analyze && flutter test
cd design && pnpm install && pnpm dev
```

## Style

- TypeScript: strict mode, ESLint + Prettier, no `any` without justification.
- Dart: null safe, feature-first structure, centralized API client and error mapping.
