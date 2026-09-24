import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:test'
import { runReminderEngine } from '../src/cron/reminder-engine'
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
})
