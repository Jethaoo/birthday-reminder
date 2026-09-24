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
cp .dev.vars.example .dev.vars   # sets JWT_SECRET; add FCM/email keys to send real pushes
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

## Running against a physical Android device

`10.0.2.2` only resolves on the Android emulator. For a real phone, start the Worker on all
interfaces and point the app at your machine's LAN address:

```powershell
# terminal 1
cd backend
pnpm exec wrangler dev --ip 0.0.0.0 --port 8787

# terminal 2 (finds your LAN IP, checks the Worker, launches the app)
powershell -ExecutionPolicy Bypass -File scripts/dev-phone.ps1
```

Debug builds allow cleartext HTTP for this workflow; release builds do not.
`powershell` is Windows PowerShell 5.1 and is present on every Windows machine; use `pwsh` instead
only if you have PowerShell 7 installed.

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
