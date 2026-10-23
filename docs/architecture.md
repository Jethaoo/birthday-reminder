# Architecture

```text
Flutter Android app
        │ HTTPS / JSON  (Authorization: Bearer <jwt>)
        ▼
Cloudflare Worker  ──  REST API, auth, validation, ownership checks
        │
        ├── D1            users, birthdays, reminders, devices, notification_logs, …
        ├── R2            optional profile photos
        └── Cron Trigger  reminder engine ──► FCM ──► Android notification
```

## Principles

- The backend owns birthday and reminder data; the app treats cached data as a read-only snapshot.
- Every record route resolves the user from the bearer token and filters by that user id.
- Reminder processing is idempotent: a unique `dedupe_key` on `notification_logs` makes repeated
  cron runs unable to send the same notification twice.
- Notification types are `birthday_today`, `birthday_tomorrow` and `birthday_advance`. The global
  reminders switch gates all three; today and tomorrow have additional independent switches.
- Android 8+ controls notification sound per channel, so the app registers
  `birthday_reminders` (with sound) and `birthday_reminders_silent`; the backend picks the channel from
  the user's sound preference.
- Dates are stored as month/day (plus optional year); the next occurrence and countdown are computed
  per request in the user's timezone.
- Authentication uses a 30-day HS256 bearer token. A password change or reset invalidates older
  tokens through `password_changed_at`, without a server-side session table.
- Home, birthdays, calendar and settings use last-known-good snapshots for offline reads. Mutations
  always go directly to the API and are never queued; a write while offline fails normally.
- Photos are private R2 objects. The app sends its bearer token only to the configured API origin,
  including when loading a photo.
- The home screen widgets are fed by a snapshot the app writes once Home has loaded, and recompute the
  countdown from the device's date themselves: no token and no network in the widget process. See
  [Home screen widgets](widgets.md).

## Layers

| Layer | Responsibility |
| --- | --- |
| `backend/src/routes` | HTTP surface, request parsing, response shaping |
| `backend/src/services` | Auth, birthdays, reminders, notifications, photos, email |
| `backend/src/lib` | Crypto, JWT, validation, errors, rate limits, timezone math and request helpers |
| `backend/src/cron` | Reminder engine invoked by the cron trigger |
| `app/lib/features/*` | Feature-first providers and presentation for auth, home, birthdays, calendar, contacts, settings and the shell |
| `app/lib/core` | API client, auth session, push, cache, widgets, errors and utilities |
| `app/lib/shared` | API models and reusable presentation widgets |
