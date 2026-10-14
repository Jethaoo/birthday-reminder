-- Lets the reminder engine retry a notification that failed for a transient
-- reason (FCM 5xx/429, network error, token exchange failure) or that was left
-- 'pending' by a run that crashed, instead of losing it for the day.
ALTER TABLE notification_logs ADD COLUMN attempts INTEGER NOT NULL DEFAULT 1;
ALTER TABLE notification_logs ADD COLUMN retryable INTEGER NOT NULL DEFAULT 0;
ALTER TABLE notification_logs ADD COLUMN updated_at TEXT;
