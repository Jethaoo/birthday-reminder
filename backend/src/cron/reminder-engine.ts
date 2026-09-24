import type { Env } from '../env'
import { sha256Hex } from '../lib/crypto'
import { newId, nowIso } from '../lib/ids'
import { addDays, localDateTime, nextOccurrence, toDateString } from '../lib/time'
import { formatOccurrenceLabel } from '../services/birthday-service'
import { sendPushToUser, type PushMessage } from '../services/notification-service'

export interface ReminderRunSummary {
  usersProcessed: number
  due: number
  sent: number
  skipped: number
  failed: number
}

export type NotificationType = 'birthday_today' | 'birthday_tomorrow' | 'birthday_advance'

export interface DueCandidate {
  userId: string
  timezone: string
  reminderId: string
  birthdayId: string
  name: string
  daysBefore: number
  occurrenceDate: string
  type: NotificationType
}

export interface ReminderWithBirthday {
  id: string
  user_id: string
  birthday_id: string
  days_before: number
  reminder_time: string
  name: string
  birthday_month: number
  birthday_day: number
  birth_year: number | null
  timezone: string
  reminders_enabled: number
  today_enabled: number
  tomorrow_enabled: number
  sound_enabled: number
}

export function notificationTypeFor(daysBefore: number): NotificationType {
  if (daysBefore === 0) return 'birthday_today'
  if (daysBefore === 1) return 'birthday_tomorrow'
  return 'birthday_advance'
}

export function notificationCopy(
  type: NotificationType,
  name: string,
  daysBefore: number,
  occurrenceLabel: string,
): Pick<PushMessage, 'title' | 'body'> {
  switch (type) {
    case 'birthday_today':
      return { title: '🎉 Birthday Today', body: `It's ${name}'s birthday today!` }
    case 'birthday_tomorrow':
      return { title: '🎂 Birthday Tomorrow', body: `${name}'s birthday is tomorrow.` }
    default:
      return {
        title: '🎂 Birthday Reminder',
        body: `${name}'s birthday is in ${daysBefore} days.\n${occurrenceLabel}`,
      }
  }
}

/**
 * Pure scheduling decision: which reminders are due for one user right now.
 * Exported so the rules can be unit tested without a database.
 */
export function dueRemindersForUser(
  rows: ReminderWithBirthday[],
  timezone: string,
  now: Date,
): DueCandidate[] {
  const local = localDateTime(now, timezone)
  const localDate = { year: local.year, month: local.month, day: local.day }
  const localTime = `${String(local.hour).padStart(2, '0')}:${String(local.minute).padStart(2, '0')}`
  const todayString = toDateString(localDate)

  const due: DueCandidate[] = []

  for (const row of rows) {
    const occurrence = nextOccurrence(row.birthday_month, row.birthday_day, localDate, row.birth_year)
    const scheduledDate = addDays(occurrence.date, -row.days_before)
    if (toDateString(scheduledDate) !== todayString) continue

    // The reminder fires on the first cron tick at or after its local time.
    if (row.reminder_time > localTime) continue

    const type = notificationTypeFor(row.days_before)
    if (type === 'birthday_today' && row.today_enabled !== 1) continue
    if (type === 'birthday_tomorrow' && row.tomorrow_enabled !== 1) continue
    if (row.reminders_enabled !== 1) continue

    due.push({
      userId: row.user_id,
      timezone,
      reminderId: row.id,
      birthdayId: row.birthday_id,
      name: row.name,
      daysBefore: row.days_before,
      occurrenceDate: toDateString(occurrence.date),
      type,
    })
  }

  return due
}

export function dedupeKeyFor(candidate: DueCandidate): Promise<string> {
  return sha256Hex(
    [candidate.userId, candidate.birthdayId, candidate.reminderId, candidate.occurrenceDate, candidate.type].join(
      '|',
    ),
  )
}

/**
 * Runs every minute from the cron trigger. Safe to run repeatedly: the unique
 * `dedupe_key` on notification_logs guarantees one notification per logical
 * event, even when two ticks overlap.
 */
export async function runReminderEngine(env: Env, now = new Date()): Promise<ReminderRunSummary> {
  const summary: ReminderRunSummary = {
    usersProcessed: 0,
    due: 0,
    sent: 0,
    skipped: 0,
    failed: 0,
  }

  const rows = await env.DB.prepare(
    `SELECT r.id, r.user_id, r.birthday_id, r.days_before, r.reminder_time,
            b.name, b.birthday_month, b.birthday_day, b.birth_year,
            u.timezone,
            COALESCE(s.reminders_enabled, 1) AS reminders_enabled,
            COALESCE(s.today_enabled, 1) AS today_enabled,
            COALESCE(s.tomorrow_enabled, 1) AS tomorrow_enabled,
            COALESCE(s.sound_enabled, 1) AS sound_enabled
       FROM reminders r
       JOIN birthdays b ON b.id = r.birthday_id
       JOIN users u ON u.id = r.user_id
       LEFT JOIN user_settings s ON s.user_id = r.user_id
      WHERE r.enabled = 1`,
  ).all<ReminderWithBirthday>()

  const byUser = new Map<string, ReminderWithBirthday[]>()
  for (const row of rows.results) {
    const list = byUser.get(row.user_id) ?? []
    list.push(row)
    byUser.set(row.user_id, list)
  }

  for (const [userId, userRows] of byUser) {
    const timezone = userRows[0]?.timezone ?? 'UTC'
    summary.usersProcessed += 1

    let candidates: DueCandidate[]
    try {
      candidates = dueRemindersForUser(userRows, timezone, now)
    } catch (error) {
      console.error('reminder_timezone_failed', { userId, error: String(error) })
      continue
    }

    for (const candidate of candidates) {
      summary.due += 1
      const inserted = await claimNotification(env, candidate)
      if (!inserted) {
        summary.skipped += 1
        continue
      }

      const settings = userRows[0] as ReminderWithBirthday
      const copy = notificationCopy(
        candidate.type,
        candidate.name,
        candidate.daysBefore,
        formatOccurrenceLabel({
          year: Number(candidate.occurrenceDate.slice(0, 4)),
          month: Number(candidate.occurrenceDate.slice(5, 7)),
          day: Number(candidate.occurrenceDate.slice(8, 10)),
        }),
      )

      const push = await sendPushToUser(env, userId, {
        ...copy,
        sound: settings.sound_enabled === 1,
        data: {
          type: candidate.type,
          birthdayId: candidate.birthdayId,
          route: `/birthdays/${candidate.birthdayId}`,
        },
      })

      if (push.sent === 0) {
        // Either every device was rejected, or the account has no devices yet.
        // Recording this as "sent" would hide a delivery that never happened.
        summary.failed += 1
        await finishNotification(
          env,
          candidate,
          'failed',
          push.failed > 0
            ? `No device accepted the notification (${push.reason ?? 'unknown'}).`
            : 'No registered devices for this account.',
        )
      } else {
        summary.sent += 1
        const note = push.simulated
          ? 'Delivery simulated: FCM credentials are not configured.'
          : push.failed > 0
            ? `Delivered to ${push.sent} device(s); ${push.failed} failed.`
            : null
        await finishNotification(env, candidate, push.failed > 0 ? 'partial' : 'sent', note)
      }
    }
  }

  return summary
}

/** Inserts the log row; a false result means another tick already claimed it. */
async function claimNotification(env: Env, candidate: DueCandidate): Promise<boolean> {
  const dedupeKey = await dedupeKeyFor(candidate)
  const result = await env.DB.prepare(
    `INSERT INTO notification_logs (
       id, user_id, birthday_id, reminder_id, device_id, notification_type,
       dedupe_key, scheduled_for, sent_at, status, error_message, created_at
     ) VALUES (?, ?, ?, ?, NULL, ?, ?, ?, NULL, 'pending', NULL, ?)
     ON CONFLICT (dedupe_key) DO NOTHING`,
  )
    .bind(
      newId(),
      candidate.userId,
      candidate.birthdayId,
      candidate.reminderId,
      candidate.type,
      dedupeKey,
      candidate.occurrenceDate,
      nowIso(),
    )
    .run()

  return (result.meta.changes ?? 0) > 0
}

async function finishNotification(
  env: Env,
  candidate: DueCandidate,
  status: 'sent' | 'failed' | 'partial',
  errorMessage: string | null,
): Promise<void> {
  const dedupeKey = await dedupeKeyFor(candidate)
  await env.DB.prepare(
    'UPDATE notification_logs SET status = ?, sent_at = ?, error_message = ? WHERE dedupe_key = ?',
  )
    .bind(status, nowIso(), errorMessage, dedupeKey)
    .run()
}
