export interface LocalDate {
  year: number
  month: number
  day: number
}

export interface LocalDateTime extends LocalDate {
  hour: number
  minute: number
}

const DATE_FORMATTERS = new Map<string, Intl.DateTimeFormat>()

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  const cached = DATE_FORMATTERS.get(timeZone)
  if (cached) return cached

  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  })
  DATE_FORMATTERS.set(timeZone, formatter)
  return formatter
}

/**
 * Resolves the wall-clock date and time for an instant in an IANA timezone.
 * Throws for unknown zones so callers can reject bad input.
 */
export function localDateTime(instant: Date, timeZone: string): LocalDateTime {
  const parts = formatterFor(timeZone).formatToParts(instant)
  const lookup = new Map(parts.map((part) => [part.type, part.value]))

  const year = Number(lookup.get('year'))
  const month = Number(lookup.get('month'))
  const day = Number(lookup.get('day'))
  const hour = Number(lookup.get('hour'))
  const minute = Number(lookup.get('minute'))

  if (![year, month, day, hour, minute].every(Number.isFinite)) {
    throw new RangeError(`Invalid timezone: ${timeZone}`)
  }

  return { year, month, day, hour, minute }
}

export function isValidTimeZone(timeZone: string): boolean {
  if (!timeZone || timeZone.length > 64) return false
  try {
    formatterFor(timeZone).format(new Date())
    return true
  } catch {
    return false
  }
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate()
}

export function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0
}

/**
 * 29 February birthdays are observed on 28 February in non-leap years.
 */
export function resolveOccurrenceDate(year: number, month: number, day: number): LocalDate {
  const maxDay = daysInMonth(year, month)
  return { year, month, day: Math.min(day, maxDay) }
}

function toUtcMillis(date: LocalDate): number {
  return Date.UTC(date.year, date.month - 1, date.day)
}

export function toDateString(date: LocalDate): string {
  const month = String(date.month).padStart(2, '0')
  const day = String(date.day).padStart(2, '0')
  return `${date.year}-${month}-${day}`
}

export function parseDateString(value: string): LocalDate | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim())
  if (!match) return null

  const [, year, month, day] = match as unknown as [string, string, string, string]
  const parsed = { year: Number(year), month: Number(month), day: Number(day) }
  if (parsed.month < 1 || parsed.month > 12) return null
  if (parsed.day < 1 || parsed.day > daysInMonth(parsed.year, parsed.month)) return null
  return parsed
}

/** Whole days from `from` to `to`; negative when `to` is earlier. */
export function daysBetween(from: LocalDate, to: LocalDate): number {
  return Math.round((toUtcMillis(to) - toUtcMillis(from)) / 86_400_000)
}

export function addDays(date: LocalDate, delta: number): LocalDate {
  const shifted = new Date(toUtcMillis(date) + delta * 86_400_000)
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  }
}

export function compareDates(a: LocalDate, b: LocalDate): number {
  return toUtcMillis(a) - toUtcMillis(b)
}

export interface Occurrence {
  date: LocalDate
  daysUntil: number
  /** Age the person turns on this occurrence, when the birth year is known. */
  turningAge: number | null
}

/**
 * Next birthday occurrence on or after `today`, evaluated in the user's
 * timezone. Returns the occurrence date, the countdown in whole days and the
 * age reached on that date.
 */
export function nextOccurrence(
  month: number,
  day: number,
  today: LocalDate,
  birthYear: number | null,
): Occurrence {
  let date = resolveOccurrenceDate(today.year, month, day)
  if (compareDates(date, today) < 0) {
    date = resolveOccurrenceDate(today.year + 1, month, day)
  }

  return {
    date,
    daysUntil: daysBetween(today, date),
    turningAge: birthYear === null ? null : date.year - birthYear,
  }
}

export function isValidMonthDay(month: number, day: number): boolean {
  if (!Number.isInteger(month) || month < 1 || month > 12) return false
  if (!Number.isInteger(day) || day < 1) return false
  // 29 February is valid so leap-day birthdays can be stored.
  if (month === 2) return day <= 29
  return day <= daysInMonth(2023, month)
}
