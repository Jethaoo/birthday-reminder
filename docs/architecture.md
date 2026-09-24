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
- Notification types are `birthday_today`, `birthday_tomorrow` and `birthday_advance`; each type is
  independently gated by the user's notification settings.
- Dates are stored as month/day (plus optional year); the next occurrence and countdown are computed
  per request in the user's timezone.

## Layers

| Layer | Responsibility |
| --- | --- |
| `backend/src/routes` | HTTP surface, request parsing, response shaping |
| `backend/src/services` | Auth, birthdays, reminders, notifications, photos, email |
| `backend/src/lib` | Crypto, JWT, validation, errors, timezone math, D1 helpers |
| `backend/src/cron` | Reminder engine invoked by the cron trigger |
| `app/lib/features/*` | One folder per feature: data, domain and presentation |
| `app/lib/core` | API client, auth session, notifications, storage, errors, utils |
