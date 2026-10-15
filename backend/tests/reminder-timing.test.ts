import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:test'
import {
  dueRemindersForUser,
  runReminderEngine,
  type ReminderWithBirthday,
} from '../src/cron/reminder-engine'
import type { Env } from '../src/env'
import { api, createBirthday, localToday, monthDayOf, registerUser } from './helpers'

const bindings = env as unknown as Env
const TIMEZONE = 'Asia/Kuala_Lumpur'

/**
 * Kuala Lumpur is a fixed UTC+8 zone with no DST, so a wall-clock time maps to
 * an instant without ambiguity. These tests pin the minute-level contract that
 * "set a reminder a few minutes from now" depends on.
 */
function instantAtLocal(isoDate: string, hhmm: string): Date {
  return new Date(`${isoDate}T${hhmm}:00+08:00`)
}

function shiftMinutes(hhmm: string, minutes: number): string {
  const [hour, minute] = hhmm.split(':').map(Number) as [number, number]
  const total = (hour * 60 + minute + minutes + 1440) % 1440
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`
}

function reminderRow(overrides: Partial<ReminderWithBirthday> = {}): ReminderWithBirthday {
  return {
    id: 'reminder-1',
    user_id: 'user-1',
    birthday_id: 'birthday-1',
    days_before: 0,
    reminder_time: '09:00',
    name: 'Sarah Tan',
    birthday_month: 9,
    birthday_day: 30,
    birth_year: 2000,
    timezone: TIMEZONE,
    reminders_enabled: 1,
    today_enabled: 1,
    tomorrow_enabled: 1,
    sound_enabled: 1,
    ...overrides,
  }
}

interface LogRow {
  notification_type: string
  status: string
  scheduled_for: string
}

async function logsFor(birthdayId: string): Promise<LogRow[]> {
  const rows = await env.DB.prepare(
    'SELECT notification_type, status, scheduled_for FROM notification_logs WHERE birthday_id = ?',
  )
    .bind(birthdayId)
    .all<LogRow>()
  return rows.results
}

async function registerDevice(user: { token: string }, fcmToken: string): Promise<void> {
  const response = await api('POST', '/api/devices', { token: user.token, body: { fcmToken } })
  if (response.status !== 201) throw new Error(`device registration failed: ${response.status}`)
}

describe('reminder timing on the scheduled day', () => {
  it('fires on the exact minute, a few minutes after the reminder was saved', async () => {
    const user = await registerUser({ timezone: TIMEZONE })
    await registerDevice(user, 'timing-token')

    const today = localToday(TIMEZONE)
    const { month, day } = monthDayOf(today.iso)

    // The reported scenario: an "On birthday" reminder saved at 21:58 for a
    // birthday that is today, firing a few minutes later at 22:01.
    const fireTime = shiftMinutes('21:58', 3)
    const birthday = await createBirthday(user, {
      name: 'Timing Test',
      birthdayMonth: month,
      birthdayDay: day,
      reminders: [{ daysBefore: 0, reminderTime: fireTime }],
    })

    // The tick that lands in the same minute the reminder was saved: not due yet.
    const savedAtTick = await runReminderEngine(bindings, instantAtLocal(today.iso, '21:58'))
    expect(savedAtTick.due).toBe(0)
    expect(await logsFor(birthday.id)).toHaveLength(0)

    // A tick one minute early must still wait.
    await runReminderEngine(bindings, instantAtLocal(today.iso, shiftMinutes(fireTime, -1)))
    expect(await logsFor(birthday.id)).toHaveLength(0)

    // The tick that lands on the configured minute delivers.
    const due = await runReminderEngine(bindings, instantAtLocal(today.iso, fireTime))
    expect(due.due).toBe(1)
    expect(due.sent).toBe(1)

    const logs = await logsFor(birthday.id)
    expect(logs).toHaveLength(1)
    expect(logs[0]).toMatchObject({
      notification_type: 'birthday_today',
      status: 'sent',
      scheduled_for: today.iso,
    })
  })

  it('catches up on the next tick when the local time already passed', async () => {
    const user = await registerUser({ timezone: TIMEZONE })
    await registerDevice(user, 'catchup-token')

    const today = localToday(TIMEZONE)
    const { month, day } = monthDayOf(today.iso)

    // Saved at 21:58 for 21:55 — the minute is already gone, so the first tick
    // at or after 21:58 is the one that delivers, rather than waiting a year.
    const birthday = await createBirthday(user, {
      name: 'Catch Up',
      birthdayMonth: month,
      birthdayDay: day,
      reminders: [{ daysBefore: 0, reminderTime: '21:55' }],
    })

    const summary = await runReminderEngine(bindings, instantAtLocal(today.iso, '21:58'))
    expect(summary.sent).toBe(1)
    expect(await logsFor(birthday.id)).toHaveLength(1)
  })

  it('delivers once even when several ticks land in the same minute', async () => {
    const user = await registerUser({ timezone: TIMEZONE })
    await registerDevice(user, 'repeat-token')

    const today = localToday(TIMEZONE)
    const { month, day } = monthDayOf(today.iso)
    const birthday = await createBirthday(user, {
      name: 'Repeat Tick',
      birthdayMonth: month,
      birthdayDay: day,
      reminders: [{ daysBefore: 0, reminderTime: '12:00' }],
    })

    const tick = instantAtLocal(today.iso, '12:00')
    await runReminderEngine(bindings, tick)
    const second = await runReminderEngine(bindings, tick)

    expect(second.due).toBe(1)
    expect(second.skipped).toBe(1)
    expect(second.sent).toBe(0)
    expect(await logsFor(birthday.id)).toHaveLength(1)
  })

  it('never fires on a day the reminder is not scheduled for', async () => {
    const user = await registerUser({ timezone: TIMEZONE })
    await registerDevice(user, 'unscheduled-token')

    const today = localToday(TIMEZONE)
    const { month, day } = monthDayOf(today.iso)

    // A birthday next month with an "On birthday" reminder: the time of day is
    // irrelevant, because the scheduled date is not today.
    const otherMonth = month === 12 ? 1 : month + 1
    const birthday = await createBirthday(user, {
      name: 'Not Today',
      birthdayMonth: otherMonth,
      // Kept valid for every month so the test holds on any run date.
      birthdayDay: Math.min(day, 28),
      reminders: [{ daysBefore: 0, reminderTime: shiftMinutes('21:58', 3) }],
    })

    await runReminderEngine(bindings, instantAtLocal(today.iso, '21:58'))
    await runReminderEngine(bindings, instantAtLocal(today.iso, shiftMinutes('21:58', 3)))
    await runReminderEngine(bindings, instantAtLocal(today.iso, '23:59'))

    expect(await logsFor(birthday.id)).toHaveLength(0)
  })
})

describe('due reminder selection at minute boundaries', () => {
  const at = (isoDate: string, hhmm: string) => instantAtLocal(isoDate, hhmm)

  it('waits until the configured minute, then fires on it', () => {
    const birthdayToday = {
      birthday_month: 9,
      birthday_day: 30,
    }
    const rows = [reminderRow({ ...birthdayToday, reminder_time: '09:03' })]

    expect(dueRemindersForUser(rows, TIMEZONE, at('2026-09-30', '09:02'))).toHaveLength(0)
    expect(dueRemindersForUser(rows, TIMEZONE, at('2026-09-30', '09:03'))).toHaveLength(1)
    expect(dueRemindersForUser(rows, TIMEZONE, at('2026-09-30', '09:04'))).toHaveLength(1)
  })

  it('reads the wall clock in the user timezone, not UTC', () => {
    const rows = [reminderRow({ birthday_month: 9, birthday_day: 30, reminder_time: '09:00' })]

    // 01:00 UTC is 09:00 in Kuala Lumpur.
    const instant = new Date('2026-09-30T01:00:00Z')
    expect(dueRemindersForUser(rows, TIMEZONE, instant)).toHaveLength(1)
    expect(dueRemindersForUser(rows, 'UTC', instant)).toHaveLength(0)
  })

  it('places an advance reminder on the birthday minus the configured days', () => {
    const scheduled = [reminderRow({ days_before: 7, reminder_time: '09:00' })]

    expect(dueRemindersForUser(scheduled, TIMEZONE, at('2026-09-23', '09:00'))).toHaveLength(1)
    expect(dueRemindersForUser(scheduled, TIMEZONE, at('2026-09-22', '09:00'))).toHaveLength(0)
    expect(dueRemindersForUser(scheduled, TIMEZONE, at('2026-09-24', '09:00'))).toHaveLength(0)
  })

  it('keeps the 28 February fallback firing on a leap day reminder', () => {
    const leapDay = [reminderRow({ birthday_month: 2, birthday_day: 29, reminder_time: '09:00' })]

    // 2027 is not a leap year, so the occurrence resolves to 28 February.
    const due = dueRemindersForUser(leapDay, TIMEZONE, at('2027-02-28', '09:00'))
    expect(due).toHaveLength(1)
    expect(due[0]?.occurrenceDate).toBe('2027-02-28')
  })
})
