-- Birthday Reminder — initial schema.
-- All timestamps are ISO-8601 UTC strings. Recurring birthdays are stored as
-- month/day plus an optional birth year.

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  -- Tokens issued before this moment are rejected, so a password reset or
  -- change invalidates existing sessions even though JWTs are stateless.
  password_changed_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE birthdays (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  normalised_name TEXT NOT NULL,
  birthday_month INTEGER NOT NULL CHECK (birthday_month BETWEEN 1 AND 12),
  -- 29 is allowed so leap-day birthdays can be stored.
  birthday_day INTEGER NOT NULL CHECK (birthday_day BETWEEN 1 AND 31),
  birth_year INTEGER,
  relationship TEXT,
  phone TEXT,
  email TEXT,
  -- Object key in R2, never a public URL.
  photo_url TEXT,
  notes TEXT,
  gift_ideas TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_birthdays_user ON birthdays (user_id);

-- Duplicate detection: same user, same normalised name, same birthday.
CREATE UNIQUE INDEX idx_birthdays_duplicate
  ON birthdays (user_id, normalised_name, birthday_month, birthday_day);

CREATE TABLE reminders (
  id TEXT PRIMARY KEY,
  birthday_id TEXT NOT NULL REFERENCES birthdays (id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  days_before INTEGER NOT NULL CHECK (days_before IN (0, 1, 3, 7, 14, 30)),
  -- Local wall-clock time in the user's timezone, HH:MM.
  reminder_time TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (birthday_id, days_before, reminder_time)
);

CREATE INDEX idx_reminders_user_enabled ON reminders (user_id, enabled);
CREATE INDEX idx_reminders_birthday ON reminders (birthday_id);

CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'android',
  device_name TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  last_seen_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_devices_user ON devices (user_id, active);

-- One row per logical notification. dedupe_key is what makes the cron trigger
-- safe to run repeatedly.
CREATE TABLE notification_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  birthday_id TEXT NOT NULL,
  reminder_id TEXT,
  device_id TEXT,
  notification_type TEXT NOT NULL,
  dedupe_key TEXT NOT NULL UNIQUE,
  scheduled_for TEXT NOT NULL,
  sent_at TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'sent', 'failed', 'partial')),
  error_message TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_notification_logs_user ON notification_logs (user_id, created_at);
CREATE INDEX idx_notification_logs_birthday ON notification_logs (birthday_id);

CREATE TABLE password_reset_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_password_reset_user ON password_reset_tokens (user_id);

CREATE TABLE user_settings (
  user_id TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  reminders_enabled INTEGER NOT NULL DEFAULT 1,
  today_enabled INTEGER NOT NULL DEFAULT 1,
  tomorrow_enabled INTEGER NOT NULL DEFAULT 1,
  sound_enabled INTEGER NOT NULL DEFAULT 1,
  default_days_before INTEGER NOT NULL DEFAULT 7,
  default_reminder_time TEXT NOT NULL DEFAULT '09:00',
  theme_mode TEXT NOT NULL DEFAULT 'system',
  updated_at TEXT NOT NULL
);

-- Fixed-window counters used for auth and write rate limiting.
CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  window_start INTEGER NOT NULL,
  count INTEGER NOT NULL
);
