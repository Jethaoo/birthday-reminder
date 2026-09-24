import { describe, expect, it } from 'vitest'
import {
  addDays,
  daysBetween,
  daysInMonth,
  isLeapYear,
  isValidMonthDay,
  isValidTimeZone,
  localDateTime,
  nextOccurrence,
  parseDateString,
  resolveOccurrenceDate,
  toDateString,
} from '../src/lib/time'

describe('timezone resolution', () => {
  it('resolves the local date and time for an instant', () => {
    const local = localDateTime(new Date('2026-09-22T17:30:00Z'), 'Asia/Kuala_Lumpur')
    expect(local).toEqual({ year: 2026, month: 9, day: 23, hour: 1, minute: 30 })
  })

  it('handles negative offsets', () => {
    const local = localDateTime(new Date('2026-09-23T02:00:00Z'), 'America/Los_Angeles')
    expect(local).toEqual({ year: 2026, month: 9, day: 22, hour: 19, minute: 0 })
  })

  it('validates IANA timezones', () => {
    expect(isValidTimeZone('Asia/Kuala_Lumpur')).toBe(true)
    expect(isValidTimeZone('UTC')).toBe(true)
    expect(isValidTimeZone('Mars/Olympus_Mons')).toBe(false)
    expect(isValidTimeZone('')).toBe(false)
  })
})

describe('date helpers', () => {
  it('counts days in a month, including leap years', () => {
    expect(daysInMonth(2026, 2)).toBe(28)
    expect(daysInMonth(2024, 2)).toBe(29)
    expect(daysInMonth(2026, 4)).toBe(30)
    expect(isLeapYear(2000)).toBe(true)
    expect(isLeapYear(1900)).toBe(false)
  })

  it('accepts 29 February but rejects impossible dates', () => {
    expect(isValidMonthDay(2, 29)).toBe(true)
    expect(isValidMonthDay(2, 30)).toBe(false)
    expect(isValidMonthDay(4, 31)).toBe(false)
    expect(isValidMonthDay(13, 1)).toBe(false)
  })

  it('round-trips date strings', () => {
    expect(toDateString({ year: 2026, month: 9, day: 3 })).toBe('2026-09-03')
    expect(parseDateString('2026-09-03')).toEqual({ year: 2026, month: 9, day: 3 })
    expect(parseDateString('2026-02-30')).toBeNull()
    expect(parseDateString('not-a-date')).toBeNull()
  })

  it('adds and subtracts calendar days across month boundaries', () => {
    expect(addDays({ year: 2026, month: 9, day: 30 }, 7)).toEqual({ year: 2026, month: 10, day: 7 })
    expect(addDays({ year: 2026, month: 1, day: 1 }, -1)).toEqual({ year: 2025, month: 12, day: 31 })
    expect(daysBetween({ year: 2026, month: 9, day: 23 }, { year: 2026, month: 9, day: 30 })).toBe(7)
  })
})

describe('next occurrence', () => {
  const today = { year: 2026, month: 9, day: 23 }

  it('returns the upcoming occurrence and countdown', () => {
    const occurrence = nextOccurrence(9, 30, today, 2000)
    expect(occurrence.date).toEqual({ year: 2026, month: 9, day: 30 })
    expect(occurrence.daysUntil).toBe(7)
    expect(occurrence.turningAge).toBe(26)
  })

  it('rolls to next year once the birthday has passed', () => {
    const occurrence = nextOccurrence(8, 30, today, 2000)
    expect(occurrence.date).toEqual({ year: 2027, month: 8, day: 30 })
    expect(occurrence.turningAge).toBe(27)
  })

  it('treats today as the next occurrence', () => {
    expect(nextOccurrence(9, 23, today, 2000).daysUntil).toBe(0)
  })

  it('observes 29 February birthdays on 28 February in non-leap years', () => {
    expect(resolveOccurrenceDate(2026, 2, 29)).toEqual({ year: 2026, month: 2, day: 28 })
    expect(resolveOccurrenceDate(2024, 2, 29)).toEqual({ year: 2024, month: 2, day: 29 })

    const occurrence = nextOccurrence(2, 29, { year: 2026, month: 2, day: 27 }, 2000)
    expect(occurrence.date).toEqual({ year: 2026, month: 2, day: 28 })
    expect(occurrence.daysUntil).toBe(1)
  })

  it('returns a null age when the birth year is unknown', () => {
    expect(nextOccurrence(9, 30, today, null).turningAge).toBeNull()
  })
})
