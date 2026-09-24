# API reference

Base URL: `https://<worker-host>` (local: `http://localhost:8787`).

All request and response bodies are JSON except photo upload (multipart) and photo reads (binary).
Protected routes require `Authorization: Bearer <jwt>`; the authenticated user is always derived from
the token, never from the request body.

## Error format

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Enter a valid email address.", "details": { "field": "email" } } }
```

| Code | HTTP | Meaning |
| --- | --- | --- |
| `UNAUTHORIZED` | 401 | Missing, expired or invalidated token; wrong credentials |
| `FORBIDDEN` | 403 | Authenticated but not allowed to touch this resource |
| `VALIDATION_ERROR` | 422 | Malformed or invalid input |
| `NOT_FOUND` | 404 | Missing resource, or another user's resource |
| `CONFLICT` | 409 | Duplicate account email, birthday or reminder |
| `RATE_LIMITED` | 429 | Too many requests; `details.retryAfterSeconds` |
| `PAYLOAD_TOO_LARGE` | 413 | Photo over 5 MB |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | Photo is not a real JPEG, PNG or WebP |
| `SERVER_ERROR` | 500 | Unexpected failure |

## Authentication

`POST /api/auth/register` — body `{ name, email, password, confirmPassword, timezone }`.
Returns `201 { user, accessToken }`. Emails are normalised to lowercase; passwords are stored as
PBKDF2-SHA256 hashes.

`POST /api/auth/login` — body `{ email, password, timezone? }`. Returns `200 { user, accessToken }`.
The same `UNAUTHORIZED` message is returned for unknown emails and wrong passwords. When `timezone`
differs from the stored value it is updated.

`POST /api/auth/logout` — client-side token discard, returns `200 { status: "signed_out" }`.

`POST /api/auth/forgot-password` — body `{ email }`. Always `202 { status: "accepted" }` so accounts
cannot be enumerated. Outside production the response also contains `resetToken` for local testing.

`POST /api/auth/reset-password` — body `{ token, password, confirmPassword }`. Single use, 60-minute
expiry. Tokens issued before the change are rejected afterwards.

## Account

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/me` | Returns `{ user }` |
| `PATCH` | `/api/me` | `{ name?, timezone? }` |
| `POST` | `/api/me/password` | `{ currentPassword, newPassword, confirmPassword }` |
| `DELETE` | `/api/me` | `{ password }` — removes the account, birthdays, reminders, devices and photos |

## Settings

`GET /api/settings` returns `{ remindersEnabled, todayEnabled, tomorrowEnabled, soundEnabled, defaultDaysBefore, defaultReminderTime, themeMode }` with defaults
`true, true, true, true, 7, "09:00", "system"`. `PATCH /api/settings` accepts any subset.

## Home

`GET /api/home` — one request for the dashboard:

```json
{
  "today": [ { "id": "…", "name": "Sarah Tan", "nextOccurrence": "2026-09-23", "daysUntil": 0, "turningAge": 26 } ],
  "upcoming": [ { "id": "…", "name": "Alex Lim", "daysUntil": 12 } ],
  "monthlySummary": { "month": 9, "monthName": "September", "year": 2026, "total": 5, "upcoming": 2, "today": 1 }
}
```

## Birthdays

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/birthdays` | Query: `search`, `filter`, `sort`, `month`, `year`, `date`, `limit`, `offset` |
| `POST` | `/api/birthdays` | Required `name`, `birthdayMonth`, `birthdayDay`; optional `birthYear`, `relationship`, `phone`, `email`, `photoUrl`, `notes`, `giftIdeas`, `reminders` |
| `GET` | `/api/birthdays/:id` | Full record including reminders |
| `PUT` | `/api/birthdays/:id` | Partial update; sending `reminders` replaces the whole set |
| `DELETE` | `/api/birthdays/:id` | Removes the birthday, its reminders, its notification logs and its photo |

Filters: `all`, `today`, `this_week`, `this_month`, `family`, `friend`, `colleague`, `other`.
Sorts: `upcoming` (default), `name`, `recently_added`.

A duplicate (same user, normalised name and date) returns `409` with
`details.existingBirthdayId`, which the app uses for the "Update existing" confirmation.

Every birthday payload includes the computed `nextOccurrence` (in the user's timezone), `daysUntil`
and `turningAge`.

## Reminders

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/birthdays/:id/reminders` | `{ items }` |
| `POST` | `/api/birthdays/:id/reminders` | `{ daysBefore, reminderTime, enabled? }` |
| `PATCH` | `/api/reminders/:id` | Change day, time or enabled |
| `DELETE` | `/api/reminders/:id` | |

`daysBefore` must be one of `0, 1, 3, 7, 14, 30`; `reminderTime` is `HH:mm` in the user's timezone.
Two reminders with the same day and time are rejected as `CONFLICT`.

## Calendar

`GET /api/calendar?month=9&year=2026` returns days that contain birthdays:

```json
{ "month": 9, "year": 2026, "days": [ { "date": "2026-09-30", "count": 1, "birthdays": [ { "id": "…", "name": "Sarah Tan", "daysUntil": 7 } ] } ] }
```

29 February birthdays resolve to 28 February in non-leap years, so the leap-day entry appears on
`2026-02-28` and on `2024-02-29`.

## Devices

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/devices` | Active devices for the account |
| `POST` | `/api/devices` | `{ fcmToken, platform?, deviceName? }`; re-registering a token refreshes it |
| `DELETE` | `/api/devices/:id` | Unregister on sign-out |

A token already owned by another account is moved to the caller, so recycled tokens never leak
notifications.

## Photos

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/api/photos` | Multipart `file`; JPEG/PNG/WebP, max 5 MB; returns `{ key, url, contentType, size }` |
| `GET` | `/api/photos/*` | Authenticated read; only the owner can fetch it |
| `DELETE` | `/api/photos/*` | Deletes the object and clears it from any birthday |

The type is detected from magic bytes, object names are generated server-side, and only the object key
is stored in D1.

## Development only

`POST /api/dev/test-notification` (body `{ birthdayId?, title?, body? }`) sends a test push to the
caller's devices and writes a `notification_logs` row. It returns `404` when
`ENVIRONMENT=production`.

## Reminder engine

The cron trigger runs every minute. For each user with enabled reminders it resolves the local date
and time, finds reminders whose scheduled date is today and whose time has arrived, and maps them to
`birthday_today`, `birthday_tomorrow` or `birthday_advance`. A unique `dedupe_key`
(user + birthday + reminder + occurrence date + type) is inserted before sending, so repeated cron
runs cannot duplicate a notification.
