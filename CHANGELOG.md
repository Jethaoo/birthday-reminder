# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each entry names the part of the monorepo it affects: **backend**, **app** or **design**.

## [Unreleased]

### Upgrade notes

- **backend:** apply migration `0003_user_profile.sql` before deploying the profile photo and
  one-time birthday features.
- **backend:** apply migration `0002_notification_retries.sql` to each D1 database **before**
  deploying this version (`wrangler d1 migrations apply <db> --env <env> --remote`). The new
  reminder engine writes the `attempts`, `retryable` and `updated_at` columns it adds.
- **backend:** if staging has been running an earlier version, rotate any account passwords there:
  earlier versions returned password-reset tokens from staging (see Security).

### Added

- **app:** The Account page can add, replace and remove a private profile photo.
- **app/backend:** Every account must set its own birthday once and cannot change it afterward.
- **app:** The Home profile avatar opens Account directly.

### Changed

- **app:** About reads the installed package version and build number instead of using a separate
  compile-time default.
- **app:** Android Back unwinds visited tabs, and Home asks for confirmation before exiting.

### Security

- **backend:** Password-reset tokens were returned in the `forgot-password` response on every
  environment except `production`, including the public staging Worker, so anyone who knew a user's
  email could take over that account. Tokens are now returned only when `ENVIRONMENT` is
  `development` or `test`. The same allow-list now guards `/api/dev/test-notification`.
- **backend:** The top-level (local) Worker is renamed `birthday-reminder-dev`, so a bare
  `wrangler deploy` can no longer overwrite the production Worker with development settings.
- **backend:** Sign-in for an unknown email now takes as long as for a real one (a PBKDF2 run on a
  dummy hash), so response time no longer reveals whether an account exists.
- **backend:** Added a per-account sign-in limit (20 per 10 minutes, across all IP addresses), and
  rate limits on the current-password checks in `POST /api/me/password` and `DELETE /api/me`.
- **backend:** Photo uploads larger than the limit are refused from `Content-Length` before the body
  is buffered, and photos are served with `X-Content-Type-Options: nosniff`.
- **app:** Signing out now unregisters the device (`DELETE /api/devices/:id`) and deletes the FCM
  token. Before, a signed-out account's reminders, which name its contacts, kept arriving on the
  phone.
- **app:** Android backup and device transfer are disabled. The offline cache holds contacts' phone
  numbers, emails and notes, and was eligible for Google Drive backup.
- **app:** The bearer token is only ever sent to the configured server, never to another host named
  in a photo URL.

### Fixed

- **backend:** Password reset could not be completed: the emailed link pointed at a page the Worker
  did not serve. The Worker now serves `GET /reset-password`, a small page that sets the new password
  (no caching, no referrer, strict CSP, token removed from the address bar).
- **backend:** Editing a birthday could send a reminder that had already fired that day a second
  time, because the reminder rows were re-created with new ids and the dedupe key included the id.
  The key is now built from the reminder's schedule instead. Notifications logged under the old key
  format are still honoured.
- **backend:** Notifications could be lost or misreported. A crash while sending one notification
  aborted the whole cron run and left that notification `pending` forever; a failed FCM OAuth token
  exchange was logged as a successful send; and FCM 5xx/429 or network errors were never retried.
  Each notification is now isolated, transient failures are retried after 5 minutes (3 attempts in
  all), and stale `pending` rows are recovered after 15 minutes.
- **backend:** Any FCM `INVALID_ARGUMENT` response deactivated the device, so a payload bug could
  silently disable every device. Devices are now deactivated only for `UNREGISTERED`, 404, or an
  invalid-registration-token error.
- **backend:** Creating or updating a birthday with an invalid reminder returned an error but still
  saved the birthday (a retry then reported "already exists"). Reminders are validated first and
  everything is saved in one transaction.
- **backend:** A token with a malformed signature returned `500` instead of `401`.
- **backend:** Replacing or clearing a birthday's photo left the old file in R2, and deleting a
  birthday could delete a photo another birthday still used. Old photos are now removed only once no
  birthday refers to them.
- **backend:** The "this week" filter covered 8 days instead of 7.
- **backend:** 29 February was accepted together with a birth year that was not a leap year.
- **backend:** An invalid `?date=` on `GET /api/birthdays` was silently ignored; it now returns `422`.
- **app:** After signing out, the next account to sign in on the same phone saw the previous
  account's birthdays, calendar and settings until it refreshed by hand. Every data screen now
  reloads when the signed-in account changes.
- **app:** An expired or revoked session looked like being offline: screens fell back to cached data
  and the user was never asked to sign in again. A `401` on any authenticated request now ends the
  session.
- **app:** "Update existing" on a duplicate birthday overwrote the saved record with the new form's
  mostly empty values, wiping its notes, phone, email, gift ideas, photo and reminders. It now keeps
  every saved value the new entry leaves empty and combines gift ideas.
- **app:** A server reply that is not the API's JSON (for example a Cloudflare 502 page) was shown as
  "No internet connection". It is now reported as a server problem.
- **app:** Restoring a session from secure storage that cannot be decrypted (for example after a
  backup was restored onto a new phone) could leave the app stuck on the loading screen.
- **app:** The calendar did not refresh after a birthday was created, edited or deleted, and the list
  and home screen did not refresh after a reminder changed.
- **app:** Changing the search, filter or sort while the next page of birthdays was loading could
  append results from the old query to the new list.
- **app:** The device was registered for push even when the notification permission was denied.
- **app:** A birthday that falls tomorrow was labelled "🎂 Tomorrow left" on its detail screen
  (and a past one "🎂 3 days ago left") where the birthday list said "Tomorrow". Both now come
  from one helper, so the two surfaces cannot disagree again.
- **app:** The app could keep showing the data it last fetched — including a cached fallback taken
  while offline — until the user pulled to refresh by hand. The dashboard, birthday list and
  calendar now revalidate when the app returns to the foreground or the connection comes back,
  in place, so nothing on screen is emptied or replaced by a spinner. The offline banner now says
  which time the data it is showing was fetched at.
- **app:** A timezone sync that could not read the stored access token wrote an empty string in its
  place, and an empty token was then restored as a valid session. The app came up showing
  signed-in screens, sent every request with no `Authorization` header, took a 401 on the first
  one and ended the session — again on every launch, until the account was signed in by hand.
  Storing a blank token is now refused, restoring one is treated as no session (and cleared), and
  a sync that cannot read the token leaves it alone.
- **app:** Opening the app signed you out. The router let the signed-in shell render while the
  stored session was still being restored, so the first request went out with no `Authorization`
  header; its 401 then ended the session that was in the middle of being restored, on every launch.
  The app now waits on a splash screen until the session has resolved, and a 401 only ends a
  session when the request that earned it actually carried the token.
- **app:** The splash screen that waits for the session never handed control back, so a session that
  restored fine sat on the spinner instead of opening the dashboard. A resolved session now goes to
  the shell, and a signed-out one to the welcome screen.

### Added

- **app:** Three Android home screen widgets: the next birthday, the next three, and today plus
  next. Home publishes a small snapshot of names and dates, and each widget recomputes the countdown
  from the device's own date using the backend's rules, so the numbers stay right overnight without
  the widget holding a token or making a request. The snapshot is deleted on sign-out, so a
  signed-out account's contacts leave the home screen.
- **app:** The actions that used to sit at the end of a long scroll — Save and Import on the add/edit
  birthday screen, Edit and Delete on a birthday's detail screen — are pinned to the bottom of the
  screen, above the system inset, so they are reachable without scrolling. "Import from contacts" is
  no longer offered while editing an existing birthday.
- **app:** A launch sequence from the design: the app mark fades and scales in, holds, then scales up
  as the app settles underneath it. It holds until the stored session has resolved, so the app is
  never revealed before it can authenticate, and it follows the system's reduced-motion setting.
  The Android launch window and the window behind the Flutter UI now use the app's own background
  colour, with a dark-mode variant, so launching no longer flashes white first.

### Changed

- **backend:** The "this week" filter now covers the calendar week (today through Sunday) instead
  of the next seven days, matching how "this month" uses the calendar month.
- **backend:** A birthday can have at most 10 reminders.
- **backend:** The reminder engine handles at most 200 due notifications per run; the rest are sent
  on the next tick.
- **backend:** Local development builds reset links against the Worker (`http://localhost:8787`).
- **app:** A release build whose `API_BASE_URL` is not `https://` now shows a clear "no server
  address" screen instead of failing every request.
- **app:** A release build without `android/key.properties` still falls back to the debug key, but
  Gradle now prints a warning that such an APK cannot later be updated by a release-signed build.

### Documentation

- **repo:** Refreshed the README, architecture, API, deployment, widget and design references against
  V1: corrected notification and offline behaviour, password-reset setup, staging test-push
  availability, response shapes and the current version.

### Not yet addressed

- **backend:** Forgot-password still answers more slowly for real accounts, because the reset email
  is sent before the response; this still reveals whether an email is registered.
- **backend:** Photos uploaded but never attached to a birthday are not cleaned up.
- **backend:** The reminder engine still reads every enabled reminder on each tick.
- **app:** The notification permission is still requested right after sign-in, without an
  explanation first.

## [1.0.0] - 2026-09-24

### Added

- Initial public release: Flutter Android app, Cloudflare Worker backend with D1, R2 and the cron
  reminder engine, and the design surface.
