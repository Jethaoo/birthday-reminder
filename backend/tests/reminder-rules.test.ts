import { describe, expect, it } from 'vitest'
import {
  dedupeKeyFor,
  dueRemindersForUser,
  notificationCopy,
  notificationTypeFor,
  type DueCandidate,
  type ReminderWithBirthday,
} from '../src/cron/reminder-engine'

const TIMEZONE = 'Asia/Kuala_Lumpur'

function reminderRow(overrides: Partial<ReminderWithBirthday> = {}): ReminderWithBirthday {
  return {
    id: 'reminder-1',
    user_id: 'user-1',
    birthday_id: 'birthday-1',
    days_before: 7,
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

describe('notification types', () => {
  it('maps reminder periods to notification types', () => {
    expect(notificationTypeFor(0)).toBe('birthday_today')
    expect(notificationTypeFor(1)).toBe('birthday_tomorrow')
    expect(notificationTypeFor(7)).toBe('birthday_advance')
  })

  it('builds the documented copy', () => {
    expect(notificationCopy('birthday_advance', 'Sarah Tan', 7, '30 September')).toEqual({
      title: '🎂 Birthday Reminder',
      body: "Sarah Tan's birthday is in 7 days.\n30 September",
    })
    expect(notificationCopy('birthday_tomorrow', 'Sarah Tan', 1, '30 September').body).toBe(
      "Sarah Tan's birthday is tomorrow.",
    )
    expect(notificationCopy('birthday_today', 'Sarah Tan', 0, '30 September').body).toBe(
      "It's Sarah Tan's birthday today!",
    )
  })
})

describe('due reminder selection', () => {
  // 09:00 on 23 September 2026 in Kuala Lumpur (UTC+8).
  const now = new Date('2026-09-23T01:00:00Z')

  it('fires an advance reminder on its scheduled day', () => {
    const due = dueRemindersForUser([reminderRow()], TIMEZONE, now)
    expect(due).toHaveLength(1)
    expect(due[0]?.type).toBe('birthday_advance')
    expect(due[0]?.occurrenceDate).toBe('2026-09-30')
  })

  it('waits until the configured local time', () => {
    expect(dueRemindersForUser([reminderRow({ reminder_time: '10:00' })], TIMEZONE, now)).toHaveLength(0)
  })

  it('does not fire on the wrong day', () => {
    expect(dueRemindersForUser([reminderRow()], TIMEZONE, new Date('2026-09-22T01:00:00Z'))).toHaveLength(0)
    expect(dueRemindersForUser([reminderRow()], TIMEZONE, new Date('2026-09-24T01:00:00Z'))).toHaveLength(0)
  })

  it('fires on-birthday and tomorrow reminders', () => {
    const today = dueRemindersForUser(
      [reminderRow({ days_before: 0, birthday_month: 9, birthday_day: 23 })],
      TIMEZONE,
      now,
    )
    expect(today[0]?.type).toBe('birthday_today')

    const tomorrow = dueRemindersForUser(
      [reminderRow({ days_before: 1, birthday_month: 9, birthday_day: 24 })],
      TIMEZONE,
      now,
    )
    expect(tomorrow[0]?.type).toBe('birthday_tomorrow')
  })

  it('respects notification preferences', () => {
    expect(dueRemindersForUser([reminderRow({ reminders_enabled: 0 })], TIMEZONE, now)).toHaveLength(0)
    expect(
      dueRemindersForUser(
        [reminderRow({ days_before: 0, birthday_month: 9, birthday_day: 23, today_enabled: 0 })],
        TIMEZONE,
        now,
      ),
    ).toHaveLength(0)
    expect(
      dueRemindersForUser(
        [reminderRow({ days_before: 1, birthday_month: 9, birthday_day: 24, tomorrow_enabled: 0 })],
        TIMEZONE,
        now,
      ),
    ).toHaveLength(0)
  })

  it('uses the user timezone, not UTC', () => {
    // 23:30 UTC is already the next calendar day in Kuala Lumpur.
    const late = new Date('2026-09-22T23:30:00Z')
    expect(dueRemindersForUser([reminderRow({ reminder_time: '07:00' })], TIMEZONE, late)).toHaveLength(1)
    expect(dueRemindersForUser([reminderRow({ reminder_time: '07:00' })], 'UTC', late)).toHaveLength(0)
  })
})

describe('dedupe keys', () => {
  const base: DueCandidate = {
    userId: 'user-1',
    timezone: TIMEZONE,
    reminderId: 'reminder-1',
    birthdayId: 'birthday-1',
    name: 'Sarah Tan',
    daysBefore: 7,
    occurrenceDate: '2026-09-30',
    type: 'birthday_advance',
  }

  it('is unique per user, birthday, reminder, occurrence and type', async () => {
    const first = await dedupeKeyFor(base)
    expect(first).toBe(await dedupeKeyFor({ ...base }))
    expect(first).not.toBe(await dedupeKeyFor({ ...base, occurrenceDate: '2027-09-30' }))
    expect(first).not.toBe(await dedupeKeyFor({ ...base, type: 'birthday_today' }))
    expect(first).not.toBe(await dedupeKeyFor({ ...base, userId: 'user-2' }))
  })
})
