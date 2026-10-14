import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:test'
import {
  legacyDedupeKeyFor,
  MAX_ATTEMPTS,
  RETRY_AFTER_MS,
  runReminderEngine,
  STALE_PENDING_MS,
} from '../src/cron/reminder-engine'
import type { Env } from '../src/env'
import { api, createBirthday, json, registerUser } from './helpers'

const bindings = env as unknown as Env
// 09:00 on 23 September 2026 in Kuala Lumpur.
const NOW = new Date('2026-09-23T01:00:00Z')

interface LogRow {
  notification_type: string
  status: string
  scheduled_for: string
  error_message: string | null
  dedupe_key: string
}

async function logsFor(birthdayId: string): Promise<LogRow[]> {
  const rows = await env.DB.prepare('SELECT * FROM notification_logs WHERE birthday_id = ?')
    .bind(birthdayId)
    .all<LogRow>()
  return rows.results
}

describe('reminder engine', () => {
  it('sends an advance reminder on the scheduled local day', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      name: 'Sarah Tan',
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'pixel-token' } })

    const summary = await runReminderEngine(bindings, NOW)
    expect(summary.sent).toBeGreaterThanOrEqual(1)

    const logs = await logsFor(birthday.id)
    expect(logs).toHaveLength(1)
    expect(logs[0]).toMatchObject({
      notification_type: 'birthday_advance',
      status: 'sent',
      scheduled_for: '2026-09-30',
    })
  })

  it('never sends the same notification twice', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'dedupe-token' } })

    const first = await runReminderEngine(bindings, NOW)
    expect(first.sent).toBeGreaterThanOrEqual(1)

    const second = await runReminderEngine(bindings, NOW)
    expect(second.skipped).toBeGreaterThanOrEqual(1)
    expect(second.sent).toBe(0)

    // A different occurrence of the same reminder is still allowed.
    const nextYear = await runReminderEngine(bindings, new Date('2027-09-23T01:00:00Z'))
    expect(nextYear.sent).toBeGreaterThanOrEqual(1)

    const logs = await logsFor(birthday.id)
    expect(logs).toHaveLength(2)
    expect(new Set(logs.map((log) => log.scheduled_for))).toEqual(
      new Set(['2026-09-30', '2027-09-30']),
    )
  })

  it('waits for the configured local time', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })

    // 00:30 UTC is 08:30 in Kuala Lumpur.
    await runReminderEngine(bindings, new Date('2026-09-23T00:30:00Z'))
    expect(await logsFor(birthday.id)).toHaveLength(0)

    await runReminderEngine(bindings, NOW)
    expect(await logsFor(birthday.id)).toHaveLength(1)
  })

  it('sends tomorrow and on-birthday notifications', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const tomorrow = await createBirthday(user, {
      name: 'Tomorrow Person',
      birthdayMonth: 9,
      birthdayDay: 24,
      reminders: [{ daysBefore: 1, reminderTime: '09:00' }],
    })
    const today = await createBirthday(user, {
      name: 'Today Person',
      birthdayMonth: 9,
      birthdayDay: 23,
      reminders: [{ daysBefore: 0, reminderTime: '09:00' }],
    })

    await runReminderEngine(bindings, NOW)

    expect((await logsFor(tomorrow.id))[0]?.notification_type).toBe('birthday_tomorrow')
    expect((await logsFor(today.id))[0]?.notification_type).toBe('birthday_today')
  })

  it('honours the user notification preferences', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 24,
      reminders: [{ daysBefore: 1, reminderTime: '09:00' }],
    })

    await api('PATCH', '/api/settings', { token: user.token, body: { tomorrowEnabled: false } })
    await runReminderEngine(bindings, NOW)
    expect(await logsFor(birthday.id)).toHaveLength(0)

    await api('PATCH', '/api/settings', { token: user.token, body: { tomorrowEnabled: true } })
    await runReminderEngine(bindings, NOW)
    expect(await logsFor(birthday.id)).toHaveLength(1)
  })

  it('skips everything when reminders are switched off', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })

    await api('PATCH', '/api/settings', { token: user.token, body: { remindersEnabled: false } })
    await runReminderEngine(bindings, NOW)
    expect(await logsFor(birthday.id)).toHaveLength(0)
  })

  it('ignores disabled reminders', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00', enabled: false }],
    })

    await runReminderEngine(bindings, NOW)
    expect(await logsFor(birthday.id)).toHaveLength(0)
  })

  it('notifies every active device and drops invalid tokens', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'phone-token' } })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'tablet-token' } })

    await runReminderEngine(bindings, NOW)

    const devices = await json<{ items: unknown[] }>(await api('GET', '/api/devices', { token: user.token }))
    expect(devices.items).toHaveLength(2)
  })

  it('never contacts FCM from the test environment', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'guard-token' } })

    const summary = await runReminderEngine(bindings, NOW)
    expect(summary.sent).toBeGreaterThanOrEqual(1)
    expect(summary.failed).toBe(0)
  })

  it('records a failure when the account has no devices', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })

    const summary = await runReminderEngine(bindings, NOW)

    expect(summary.sent).toBe(0)
    expect(summary.failed).toBeGreaterThanOrEqual(1)
    const log = (await logsFor(birthday.id))[0]
    expect(log?.status).toBe('failed')
    expect(log?.error_message).toContain('No registered devices')
  })

  it('does not resend a reminder after the birthday is edited', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'edit-token' } })
    await runReminderEngine(bindings, NOW)

    // Saving the edit screen re-sends the reminders, which replaces the rows.
    const edit = await api('PUT', `/api/birthdays/${birthday.id}`, {
      token: user.token,
      body: { notes: 'Bring cake', reminders: [{ daysBefore: 7, reminderTime: '09:00' }] },
    })
    expect(edit.status).toBe(200)

    // 15:00 the same local day: the reminder is still "due", but already sent.
    const later = await runReminderEngine(bindings, new Date('2026-09-23T07:00:00Z'))
    expect(later.sent).toBe(0)
    expect(await logsFor(birthday.id)).toHaveLength(1)
  })

  it('respects notifications logged under the previous key format', async () => {
    const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
    const birthday = await createBirthday(user, {
      birthdayMonth: 9,
      birthdayDay: 30,
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    const reminder = await env.DB.prepare('SELECT id FROM reminders WHERE birthday_id = ?')
      .bind(birthday.id)
      .first<{ id: string }>()
    const legacyKey = await legacyDedupeKeyFor({
      userId: user.id,
      timezone: 'Asia/Kuala_Lumpur',
      reminderId: reminder?.id ?? '',
      birthdayId: birthday.id,
      name: 'Sarah Tan',
      daysBefore: 7,
      reminderTime: '09:00',
      occurrenceDate: '2026-09-30',
      type: 'birthday_advance',
    })
    await env.DB.prepare(
      `INSERT INTO notification_logs (id, user_id, birthday_id, reminder_id, notification_type,
         dedupe_key, scheduled_for, sent_at, status, created_at)
       VALUES (?, ?, ?, ?, 'birthday_advance', ?, '2026-09-30', ?, 'sent', ?)`,
    )
      .bind(crypto.randomUUID(), user.id, birthday.id, reminder?.id, legacyKey, NOW.toISOString(), NOW.toISOString())
      .run()

    const summary = await runReminderEngine(bindings, NOW)
    expect(summary.sent).toBe(0)
    expect(await logsFor(birthday.id)).toHaveLength(1)
  })

  describe('retries', () => {
    async function seedFailedNotification(fields: { status: string; retryable: number; attempts: number }) {
      const user = await registerUser({ timezone: 'Asia/Kuala_Lumpur' })
      const birthday = await createBirthday(user, {
        birthdayMonth: 9,
        birthdayDay: 30,
        reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
      })
      await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'retry-token' } })
      // First run sends; then rewrite the row to the state under test.
      await runReminderEngine(bindings, NOW)
      await env.DB.prepare(
        'UPDATE notification_logs SET status = ?, retryable = ?, attempts = ?, updated_at = ? WHERE birthday_id = ?',
      )
        .bind(fields.status, fields.retryable, fields.attempts, NOW.toISOString(), birthday.id)
        .run()
      return birthday
    }

    const AFTER_RETRY_DELAY = new Date(NOW.getTime() + RETRY_AFTER_MS)
    const AFTER_STALE_DELAY = new Date(NOW.getTime() + STALE_PENDING_MS)

    it('retries a transient failure after the delay', async () => {
      const birthday = await seedFailedNotification({ status: 'failed', retryable: 1, attempts: 1 })

      const tooSoon = await runReminderEngine(bindings, new Date(NOW.getTime() + 60_000))
      expect(tooSoon.sent).toBe(0)

      const retried = await runReminderEngine(bindings, AFTER_RETRY_DELAY)
      expect(retried.sent).toBeGreaterThanOrEqual(1)
      const row = await env.DB.prepare('SELECT status, attempts FROM notification_logs WHERE birthday_id = ?')
        .bind(birthday.id)
        .first<{ status: string; attempts: number }>()
      expect(row).toEqual({ status: 'sent', attempts: 2 })
    })

    it('does not retry a permanent failure', async () => {
      await seedFailedNotification({ status: 'failed', retryable: 0, attempts: 1 })
      const summary = await runReminderEngine(bindings, AFTER_STALE_DELAY)
      expect(summary.sent).toBe(0)
    })

    it('stops after the maximum number of attempts', async () => {
      await seedFailedNotification({ status: 'failed', retryable: 1, attempts: MAX_ATTEMPTS })
      const summary = await runReminderEngine(bindings, AFTER_STALE_DELAY)
      expect(summary.sent).toBe(0)
    })

    it('recovers a notification left pending by a crashed run', async () => {
      await seedFailedNotification({ status: 'pending', retryable: 0, attempts: 1 })

      const tooSoon = await runReminderEngine(bindings, AFTER_RETRY_DELAY)
      expect(tooSoon.sent).toBe(0)

      const recovered = await runReminderEngine(bindings, AFTER_STALE_DELAY)
      expect(recovered.sent).toBeGreaterThanOrEqual(1)
    })
  })
})
