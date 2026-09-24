# Birthday Reminder — Flutter app

The Android client. See the [root README](../README.md) for the project overview, the backend and the
design surface.

## Run it

```bash
flutter pub get

# Emulator talking to a Worker on the host machine:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787

# Physical device: ../scripts/dev-phone.ps1 finds your LAN address and launches
# the app against it.
```

Debug builds allow cleartext HTTP so they can reach a local Worker. Release builds refuse it, so a
release build must be pointed at an `https://` API:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-worker.workers.dev \
  --dart-define=APP_VERSION=1.0.0
```

## Structure

```text
lib/
├── app/        theme tokens, router and app shell
├── core/       API client, session, push, cache, utilities
├── features/   auth, home, birthdays, calendar, contacts, settings, shell
└── shared/     models and reusable widgets
```

`assets/fonts` bundles DM Sans and Fraunces so typography never depends on a runtime download.

## Checks

```bash
flutter analyze
flutter test
```

## Release signing

Release builds read `android/key.properties` when it exists and otherwise fall back to the debug keys,
so you can build without the upload keystore. See the deployment runbook for creating one.
