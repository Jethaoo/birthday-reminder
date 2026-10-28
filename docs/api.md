# API reference

Base URL: `https://<worker-host>`. A local Worker listens on `http://localhost:8787`; the Android
emulator reaches it at `http://10.0.2.2:8787`.

Unless noted, API request and response bodies are JSON. Photo upload is multipart, photo reads are
binary, and the password-reset page is HTML with a separate JavaScript asset. Protected routes
require `Authorization: Bearer <jwt>`; the authenticated user is always derived from the token,
never from the request body.

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

The Flutter client maps connection failures and timeouts to its local `NETWORK_ERROR` code and a
non-JSON server response to `SERVER_ERROR`.

## Rate limits

Limits use fixed 10-minute or 1-hour windows and return `429 RATE_LIMITED` with
`details.retryAfterSeconds`:

- 5 registration, sign-in, forgot-password or reset-password requests per 10 minutes per client.
- 20 sign-in attempts per 10 minutes per account, even across different client addresses.
- 5 current-password checks per 10 minutes for password changes and account deletion.
- 60 birthday create/update requests, 20 device registrations or 30 photo uploads per hour per
  account.

## Health

`GET /health` is public and returns `200 { "status": "ok", "environment": "<environment>" }`.

## Authentication

`POST /api/auth/register` — body `{ name, email, password, confirmPassword, timezone? }`. A missing
timezone defaults to `UTC`. Returns `201 { user, accessToken }`. Emails are normalised to lowercase;
passwords are stored as PBKDF2-SHA256 hashes.

`POST /api/auth/login` — body `{ email, password, timezone? }`. Returns `200 { user, accessToken }`.
The same `UNAUTHORIZED` message is returned for unknown emails and wrong passwords. When `timezone`
differs from the stored value it is updated.

Passwords are 8–128 characters and must contain at least one letter and one digit.

`POST /api/auth/logout` — client-side token discard, returns `200 { status: "signed_out" }`.

`POST /api/auth/forgot-password` — body `{ email }`. Always `202 { status: "accepted" }` so accounts
cannot be enumerated. Email is sent only when both `RESEND_API_KEY` and `EMAIL_FROM` are configured.
Only when `ENVIRONMENT` is `development` or `test` does the response also contain `resetToken`, for
local testing; staging and production never return it.

The emailed link opens `GET /reset-password?token=…`, a small page served by the Worker that
collects the new password and calls `POST /api/auth/reset-password`. Its script is served from
`GET /reset-password.js`.

`POST /api/auth/reset-password` — body `{ token, password, confirmPassword }`. Single use, 60-minute
expiry. Tokens issued before the change are rejected afterwards.

## Account

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/me` | Returns `{ user }`, including profile photo and one-time birthday fields |
| `PATCH` | `/api/me` | `{ name?, timezone?, photoUrl? }`; `photoUrl: null` removes the profile photo |
| `PUT` | `/api/me/birthday` | `{ birthdayMonth, birthdayDay, birthYear? }`; can be called successfully only once |
| `POST` | `/api/me/password` | `{ currentPassword, newPassword, confirmPassword }`; old tokens stop working |
| `DELETE` | `/api/me` | `{ password }` — removes the account, birthdays, reminders, devices, photos, reset tokens and settings |

## Settings

`GET /api/settings` returns `{ remindersEnabled, todayEnabled, tomorrowEnabled, soundEnabled, defaultDaysBefore, defaultReminderTime, themeMode }` with defaults
`true, true, true, true, 7, "09:00", "system"`. `PATCH /api/settings` accepts one or more of those
fields and returns the complete settings object.

## Home

`GET /api/home` — one request for the dashboard:

```json
{
  "today": [ { "id": "…", "name": "Sarah Tan", "nextOccurrence": "2026-09-23", "daysUntil": 0, "turningAge": 26 } ],
  "upcoming": [ { "id": "…", "name": "Alex Lim", "daysUntil": 12 } ],
  "monthlySummary": { "month": 9, "monthName": "September", "year": 2026, "total": 5, "upcoming": 2, "today": 1 }
}
```

`today` contains every birthday occurring today. `upcoming` contains at most the next five.
`monthlySummary` counts the occurrences that fall in the user's current local month; a date that has
already passed this month has rolled over to next year and is not included.

## Birthdays

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/birthdays` | Query: `search`, `filter`, `sort`, `month`, `year`, `date`, `limit`, `offset`; returns `{ items, total, limit, offset }` |
| `POST` | `/api/birthdays` | Required `name`, `birthdayMonth`, `birthdayDay`; optional `birthYear`, `relationship`, `phone`, `email`, `photoUrl`, `notes`, `giftIdeas`, `reminders`; returns `201` with the full record |
| `GET` | `/api/birthdays/:id` | Full record including reminders |
| `PUT` | `/api/birthdays/:id` | Partial update; sending `reminders` replaces the whole set; returns the full record |
| `DELETE` | `/api/birthdays/:id` | Removes the birthday, its reminders and its notification logs; deletes the photo once no other birthday uses it |

Filters: `all`, `today`, `this_week`, `this_month`, `family`, `friend`, `colleague`, `other`.
`this_week` is the calendar week (Monday to Sunday) and `this_month` the calendar month, both in
the user's timezone and counting only birthdays from today on.
Sorts: `upcoming` (default), `name`, `recently_added`.
`limit` defaults to 50 and accepts 1–200; `offset` defaults to 0. `month` accepts 1–12, `year`
accepts 1900–2200, and `date` must be `YYYY-MM-DD`. `year` is used together with `month`; an exact
`date` takes precedence over `filter`.

A duplicate (same user, normalised name and date) returns `409` with
`details.existingBirthdayId`, which the app uses for the "Update existing" confirmation.

Every birthday payload includes the computed `nextOccurrence` (in the user's timezone), `daysUntil`
and `turningAge`. A full record also includes notes, gifts, contact details, photo URL, timestamps
and its reminders. A birthday can have at most 10 reminders.

## Reminders

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/birthdays/:id/reminders` | `{ items }` |
| `POST` | `/api/birthdays/:id/reminders` | `{ daysBefore, reminderTime, enabled? }`; returns `201` with the reminder |
| `PATCH` | `/api/reminders/:id` | Change day, time or enabled; returns the reminder |
| `DELETE` | `/api/reminders/:id` | |

`daysBefore` must be one of `0, 1, 3, 7, 14, 30`; `reminderTime` is `HH:mm` in the user's timezone.
The standalone create/update routes reject a duplicate day and time as `409 CONFLICT`. When the app
sends a complete `reminders` array with a birthday, duplicate pairs are rejected as
`422 VALIDATION_ERROR` before anything is written.

## Calendar

`GET /api/calendar?month=9&year=2026` returns days that contain birthdays. Both parameters are
optional and default to the user's current local month and year:

```json
{ "month": 9, "year": 2026, "days": [ { "date": "2026-09-30", "count": 1, "birthdays": [ { "id": "…", "name": "Sarah Tan", "daysUntil": 7 } ] } ] }
```

29 February birthdays resolve to 28 February in non-leap years, so the leap-day entry appears on
`2026-02-28` and on `2024-02-29`.

## Devices

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/api/devices` | Active devices as `{ items }` |
| `POST` | `/api/devices` | `{ fcmToken, platform?, deviceName? }`; re-registering a token refreshes it and returns the device |
| `DELETE` | `/api/devices/:id` | Unregister on sign-out; returns `{ status: "deleted" }` |

A token already owned by another account is moved to the caller, so recycled tokens never leak
notifications.

## Photos

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/api/photos` | Multipart `file`; JPEG/PNG/WebP, max 5 MB; returns `{ key, url, contentType, size }` |
| `GET` | `/api/photos/*` | Authenticated read; only the owner can fetch it |
| `DELETE` | `/api/photos/*` | Deletes the object and clears it from any birthday or account profile |

The type is detected from magic bytes, object names are generated server-side, and only the object key
is stored in D1.

## Development only

`POST /api/dev/test-notification` (body `{ birthdayId?, title?, body? }`) sends a test push to the
caller's devices and writes a `notification_logs` row. It returns `404` unless `ENVIRONMENT` is
`development` or `test`, so it is unavailable on staging and production. The response reports
`{ sent, failed, simulated, reason }` instead of assuming delivery succeeded.

## Reminder engine

The cron trigger runs every minute. For each user with enabled reminders it resolves the local date
and time, finds reminders whose scheduled date is today and whose time has arrived, and maps them to
`birthday_today`, `birthday_tomorrow` or `birthday_advance`. A unique `dedupe_key`
(user + birthday + days before + reminder time + occurrence date + type) is inserted before sending,
so repeated cron runs cannot duplicate a notification. The key does not include the reminder row id,
because editing a birthday re-creates its reminder rows; an edit therefore never re-sends a reminder
that already fired.

A delivery that fails for a transient reason (FCM 5xx or 429, a network error, a failed OAuth token
exchange) is retried after 5 minutes, up to 3 attempts in all. A row left `pending` by a run that died
is picked up again after 15 minutes. Permanent failures, such as an account with no devices, are not
retried. Each run handles at most 200 due notifications; any beyond that are sent on the next tick.
