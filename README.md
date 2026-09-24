# Birthday Reminder

Production-ready Android birthday reminder app: birthdays, recurring reminders, server push
notifications, calendar, search and contact import.

- **App**: Flutter / Dart, Material 3, Android only
- **Backend**: Cloudflare Workers (TypeScript) + D1 + Cron Triggers
- **Push**: Firebase Cloud Messaging
- **Photos**: Cloudflare R2
- **Design**: the original Figma Make prototype, kept runnable in `design/`

AI birthday wishes are deliberately out of scope for V1.

## Repository layout

```text
birthday/
├── app/          Flutter Android application
├── backend/      Cloudflare Worker REST API, D1 migrations, cron reminder engine
├── design/       Figma Make prototype extended into the full V1 design surface
├── docs/         API reference, architecture and deployment runbook
└── README.md
```

## Quick start

```bash
# Backend (local D1 + Worker on :8787)
cd backend
pnpm install
pnpm db:migrate:local
pnpm dev

# Flutter app
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787

# Design reference (React + Vite, :8443)
cd design
pnpm install
pnpm dev
```

## Checks

```bash
cd backend && pnpm test && pnpm typecheck
cd app && flutter analyze && flutter test
```

CI runs the same commands on every pull request.

## Documentation

- [Architecture](docs/architecture.md)
- [API reference](docs/api.md)
- [Deployment runbook](docs/deployment.md)
