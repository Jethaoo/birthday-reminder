import type { Env } from '../env'
import { ApiError } from '../lib/errors'
import { newId, normaliseName, nowIso } from '../lib/ids'
import {
  compareDates,
  daysBetween,
  localDateTime,
  nextOccurrence,
  parseDateString,
  resolveOccurrenceDate,
  toDateString,
  type LocalDate,
} from '../lib/time'
import {
  asRecord,
  giftIdeas,
  optionalEmail,
  optionalInt,
  optionalString,
  requiredInt,
  requiredString,
  validateBirthdayDate,
} from '../lib/validation'
import {
  toReminderDto,
  type BirthdayDto,
  type BirthdayRow,
  type BirthdaySummaryDto,
  type CalendarDto,
  type CalendarDayDto,
  type HomeDto,
  type ReminderRow,
  type UserRow,
} from '../models'
import { isUniqueViolation, replaceReminders } from './reminder-service'
import { keyFromPhotoUrl, photoUrl, storedPhotoUrl } from './photo-service'

export type BirthdayFilter =
  | 'all'
  | 'today'
  | 'this_week'
  | 'this_month'
  | 'family'
  | 'friend'
  | 'colleague'
  | 'other'

export type BirthdaySort = 'upcoming' | 'name' | 'recently_added'

export interface BirthdayListQuery {
  search: string | null
  filter: BirthdayFilter
  sort: BirthdaySort
  month: number | null
  year: number | null
  date: string | null
  limit: number
  offset: number
}

const RELATIONSHIP_FILTERS: Record<string, string> = {
  family: 'family',
  friend: 'friend',
  colleague: 'colleague',
}

const MIN_BIRTH_YEAR = 1900

interface LoadedBirthdays {
  birthdays: BirthdayRow[]
  reminders: ReminderRow[]
  today: LocalDate
  timezone: string
}

async function loadBirthdays(env: Env, user: UserRow): Promise<LoadedBirthdays> {
  const [birthdays, reminders, today] = await Promise.all([
    env.DB.prepare('SELECT * FROM birthdays WHERE user_id = ?').bind(user.id).all<BirthdayRow>(),
    env.DB.prepare('SELECT * FROM reminders WHERE user_id = ?').bind(user.id).all<ReminderRow>(),
    Promise.resolve(localDateTime(new Date(), user.timezone)),
  ])

  return {
    birthdays: birthdays.results,
    reminders: reminders.results,
    today,
    timezone: user.timezone,
  }
}

function toSummary(row: BirthdayRow, today: LocalDate): BirthdaySummaryDto {
  const occurrence = nextOccurrence(row.birthday_month, row.birthday_day, today, row.birth_year)
  return {
    id: row.id,
    name: row.name,
    birthdayMonth: row.birthday_month,
    birthdayDay: row.birthday_day,
    birthYear: row.birth_year,
    relationship: row.relationship,
    photoUrl: storedPhotoUrl(row.photo_url),
    nextOccurrence: toDateString(occurrence.date),
    daysUntil: occurrence.daysUntil,
    turningAge: occurrence.turningAge,
  }
}

function toBirthdayDto(row: BirthdayRow, today: LocalDate, reminders: ReminderRow[]): BirthdayDto {
  const occurrence = nextOccurrence(row.birthday_month, row.birthday_day, today, row.birth_year)
  return {
    ...toSummary(row, today),
    phone: row.phone,
    email: row.email,
    notes: row.notes,
    giftIdeas: parseGiftIdeas(row.gift_ideas),
    reminders: reminders
      .filter((reminder) => reminder.birthday_id === row.id)
      .sort((a, b) => b.days_before - a.days_before)
      .map(toReminderDto),
    nextOccurrence: toDateString(occurrence.date),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

function parseGiftIdeas(value: string): string[] {
  try {
    const parsed = JSON.parse(value)
    return Array.isArray(parsed) ? parsed.map(String) : []
  } catch {
    return []
  }
}

function matchesFilter(row: BirthdayRow, daysUntil: number, occurrence: LocalDate, query: BirthdayListQuery, today: LocalDate): boolean {
  const relationship = (row.relationship ?? '').toLowerCase()

  switch (query.filter) {
    case 'all':
      break
    case 'today':
      return daysUntil === 0
    case 'this_week':
      return daysUntil <= 7
    case 'this_month':
      return occurrence.year === today.year && occurrence.month === today.month
    case 'other':
      return !Object.values(RELATIONSHIP_FILTERS).includes(relationship)
    default:
      return relationship === RELATIONSHIP_FILTERS[query.filter]
  }

  return true
}

function matchesSearch(row: BirthdayRow, search: string | null): boolean {
  if (!search) return true
  const term = search.trim().toLowerCase()
  if (!term) return true
  return [row.name, row.relationship, row.notes].some((value) =>
    (value ?? '').toLowerCase().includes(term),
  )
}

export async function listBirthdays(
  env: Env,
  user: UserRow,
  query: BirthdayListQuery,
): Promise<{ items: BirthdayDto[]; total: number; limit: number; offset: number }> {
  const { birthdays, reminders, today } = await loadBirthdays(env, user)

  const decorated = birthdays.map((row) => {
    const occurrence = nextOccurrence(row.birthday_month, row.birthday_day, today, row.birth_year)
    return { row, occurrence }
  })

  const dateFilter = query.date ? parseDateString(query.date) : null

  const filtered = decorated.filter(({ row, occurrence }) => {
    if (!matchesSearch(row, query.search)) return false

    if (dateFilter) {
      // `nextOccurrence` only spans the current and next year, so a date in the
      // queried year is compared against that year's resolved date.
      const target = resolveOccurrenceDate(
        dateFilter.year,
        row.birthday_month,
        row.birthday_day,
      )
      return compareDates(target, dateFilter) === 0
    }

    if (query.month !== null) {
      const year = query.year ?? today.year
      const target = resolveOccurrenceDate(year, row.birthday_month, row.birthday_day)
      if (target.month !== query.month) return false
      if (query.year !== null && target.year !== query.year) return false
      return true
    }

    return matchesFilter(row, occurrence.daysUntil, occurrence.date, query, today)
  })

  const sorted = filtered.sort((a, b) => {
    switch (query.sort) {
      case 'name':
        return a.row.name.toLowerCase().localeCompare(b.row.name.toLowerCase())
      case 'recently_added':
        return b.row.created_at.localeCompare(a.row.created_at)
      default:
        return (
          a.occurrence.daysUntil - b.occurrence.daysUntil ||
          a.row.name.toLowerCase().localeCompare(b.row.name.toLowerCase())
        )
    }
  })

  const page = sorted.slice(query.offset, query.offset + query.limit)

  return {
    items: page.map(({ row }) => toBirthdayDto(row, today, reminders)),
    total: sorted.length,
    limit: query.limit,
    offset: query.offset,
  }
}

export async function getBirthday(env: Env, user: UserRow, birthdayId: string): Promise<BirthdayDto> {
  const row = await env.DB.prepare('SELECT * FROM birthdays WHERE id = ? AND user_id = ?')
    .bind(birthdayId, user.id)
    .first<BirthdayRow>()
  if (!row) throw ApiError.notFound('Birthday not found.')

  const reminders = await env.DB.prepare('SELECT * FROM reminders WHERE birthday_id = ?')
    .bind(birthdayId)
    .all<ReminderRow>()
  const today = localDateTime(new Date(), user.timezone)
  return toBirthdayDto(row, today, reminders.results)
}

interface BirthdayFields {
  name: string
  birthdayMonth: number
  birthdayDay: number
  birthYear: number | null
  relationship: string | null
  phone: string | null
  email: string | null
  photoUrl: string | null
  notes: string | null
  giftIdeas: string[]
}

function parseBirthdayFields(body: unknown, existing?: BirthdayRow): BirthdayFields {
  const input = asRecord(body)
  const has = (field: string) => input[field] !== undefined
  const currentYear = new Date().getUTCFullYear()

  const { month, day } = validateBirthdayDate(
    has('birthdayMonth') ? input.birthdayMonth : existing?.birthday_month,
    has('birthdayDay') ? input.birthdayDay : existing?.birthday_day,
  )

  const birthYear = has('birthYear')
    ? optionalInt(input.birthYear, 'Birth year', { min: MIN_BIRTH_YEAR, max: currentYear })
    : (existing?.birth_year ?? null)

  return {
    name: has('name')
      ? requiredString(input.name, 'Name', { max: 120 })
      : requiredString(existing?.name, 'Name', { max: 120 }),
    birthdayMonth: month,
    birthdayDay: day,
    birthYear,
    relationship: has('relationship')
      ? optionalString(input.relationship, 'Relationship', { max: 60 })
      : (existing?.relationship ?? null),
    phone: has('phone') ? optionalString(input.phone, 'Phone', { max: 40 }) : (existing?.phone ?? null),
    email: has('email') ? optionalEmail(input.email) : (existing?.email ?? null),
    photoUrl: has('photoUrl') ? optionalString(input.photoUrl, 'Photo', { max: 300 }) : null,
    notes: has('notes') ? optionalString(input.notes, 'Notes', { max: 4000 }) : (existing?.notes ?? null),
    giftIdeas: has('giftIdeas') ? giftIdeas(input.giftIdeas) : parseGiftIdeas(existing?.gift_ideas ?? '[]'),
  }
}

function photoKeyFor(userId: string, url: string | null): string | null {
  if (!url) return null
  const key = url.startsWith('/api/photos/') ? keyFromPhotoUrl(url) : url
  if (!key.startsWith(`photos/${userId}/`)) {
    throw ApiError.forbidden('You do not have access to this photo.')
  }
  return key
}

export async function createBirthday(env: Env, user: UserRow, body: unknown): Promise<BirthdayDto> {
  const fields = parseBirthdayFields(body)
  const id = newId()
  const timestamp = nowIso()

  try {
    await env.DB.prepare(
      `INSERT INTO birthdays (
         id, user_id, name, normalised_name, birthday_month, birthday_day, birth_year,
         relationship, phone, email, photo_url, notes, gift_ideas, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        id,
        user.id,
        fields.name,
        normaliseName(fields.name),
        fields.birthdayMonth,
        fields.birthdayDay,
        fields.birthYear,
        fields.relationship,
        fields.phone,
        fields.email,
        photoKeyFor(user.id, fields.photoUrl),
        fields.notes,
        JSON.stringify(fields.giftIdeas),
        timestamp,
        timestamp,
      )
      .run()
  } catch (error) {
    if (isUniqueViolation(error)) throw await duplicateError(env, user, fields)
    throw error
  }

  const input = asRecord(body)
  if (Array.isArray(input.reminders) && input.reminders.length > 0) {
    await replaceReminders(env, user.id, id, input.reminders)
  }

  return getBirthday(env, user, id)
}

export async function updateBirthday(
  env: Env,
  user: UserRow,
  birthdayId: string,
  body: unknown,
): Promise<BirthdayDto> {
  const existing = await env.DB.prepare('SELECT * FROM birthdays WHERE id = ? AND user_id = ?')
    .bind(birthdayId, user.id)
    .first<BirthdayRow>()
  if (!existing) throw ApiError.notFound('Birthday not found.')

  const fields = parseBirthdayFields(body, existing)
  const photoKey =
    asRecord(body).photoUrl === undefined ? existing.photo_url : photoKeyFor(user.id, fields.photoUrl)

  try {
    await env.DB.prepare(
      `UPDATE birthdays SET
         name = ?, normalised_name = ?, birthday_month = ?, birthday_day = ?, birth_year = ?,
         relationship = ?, phone = ?, email = ?, photo_url = ?, notes = ?, gift_ideas = ?, updated_at = ?
       WHERE id = ? AND user_id = ?`,
    )
      .bind(
        fields.name,
        normaliseName(fields.name),
        fields.birthdayMonth,
        fields.birthdayDay,
        fields.birthYear,
        fields.relationship,
        fields.phone,
        fields.email,
        photoKey,
        fields.notes,
        JSON.stringify(fields.giftIdeas),
        nowIso(),
        birthdayId,
        user.id,
      )
      .run()
  } catch (error) {
    if (isUniqueViolation(error)) throw await duplicateError(env, user, fields, birthdayId)
    throw error
  }

  const input = asRecord(body)
  if (input.reminders !== undefined) {
    await replaceReminders(env, user.id, birthdayId, input.reminders)
  }

  return getBirthday(env, user, birthdayId)
}

export async function deleteBirthday(env: Env, user: UserRow, birthdayId: string): Promise<void> {
  const row = await env.DB.prepare('SELECT photo_url FROM birthdays WHERE id = ? AND user_id = ?')
    .bind(birthdayId, user.id)
    .first<{ photo_url: string | null }>()
  if (!row) throw ApiError.notFound('Birthday not found.')

  await env.DB.batch([
    env.DB.prepare('DELETE FROM notification_logs WHERE birthday_id = ? AND user_id = ?')
      .bind(birthdayId, user.id),
    env.DB.prepare('DELETE FROM reminders WHERE birthday_id = ?').bind(birthdayId),
    env.DB.prepare('DELETE FROM birthdays WHERE id = ? AND user_id = ?').bind(birthdayId, user.id),
  ])

  if (row.photo_url) await env.PHOTOS.delete(row.photo_url)
}

async function duplicateError(
  env: Env,
  user: UserRow,
  fields: BirthdayFields,
  excludeId?: string,
): Promise<ApiError> {
  const existing = await env.DB.prepare(
    'SELECT id FROM birthdays WHERE user_id = ? AND normalised_name = ? AND birthday_month = ? AND birthday_day = ?',
  )
    .bind(user.id, normaliseName(fields.name), fields.birthdayMonth, fields.birthdayDay)
    .first<{ id: string }>()

  return ApiError.conflict('This birthday already exists.', {
    existingBirthdayId: existing && existing.id !== excludeId ? existing.id : null,
  })
}

export async function homeSummary(env: Env, user: UserRow, upcomingLimit = 5): Promise<HomeDto> {
  const { birthdays, reminders, today } = await loadBirthdays(env, user)
  const dtos = birthdays.map((row) => toBirthdayDto(row, today, reminders))

  const todayList = dtos.filter((item) => item.daysUntil === 0)
  const upcoming = dtos
    .filter((item) => item.daysUntil > 0)
    .sort((a, b) => a.daysUntil - b.daysUntil)
    .slice(0, upcomingLimit)

  const monthOccurrences = dtos.filter((item) => {
    const occurrence = parseDateString(item.nextOccurrence)
    return occurrence && occurrence.month === today.month && occurrence.year === today.year
  })

  return {
    today: todayList,
    upcoming,
    monthlySummary: {
      month: today.month,
      monthName: monthName(today.month),
      year: today.year,
      total: monthOccurrences.length,
      upcoming: monthOccurrences.filter((item) => item.daysUntil > 0).length,
      today: todayList.length,
    },
  }
}

export async function calendarSummary(
  env: Env,
  user: UserRow,
  month: number,
  year: number,
): Promise<CalendarDto> {
  const { birthdays, today } = await loadBirthdays(env, user)
  const byDate = new Map<string, CalendarDayDto>()

  for (const row of birthdays) {
    const target = resolveOccurrenceDate(year, row.birthday_month, row.birthday_day)
    if (target.month !== month || target.year !== year) continue

    const date = toDateString(target)
    const summary = toSummary(row, today)
    const day = byDate.get(date) ?? { date, count: 0, birthdays: [] }
    day.birthdays.push(summary)
    day.count += 1
    byDate.set(date, day)
  }

  return {
    month,
    year,
    days: [...byDate.values()].sort((a, b) => a.date.localeCompare(b.date)),
  }
}

export function daysUntilOccurrence(month: number, day: number, today: LocalDate): number {
  const date = resolveOccurrenceDate(today.year, month, day)
  const target = compareDates(date, today) < 0 ? resolveOccurrenceDate(today.year + 1, month, day) : date
  return daysBetween(today, target)
}

function monthName(month: number): string {
  return new Intl.DateTimeFormat('en-GB', { month: 'long', timeZone: 'UTC' }).format(
    new Date(Date.UTC(2024, month - 1, 1)),
  )
}

/** Validates a `limit`/`offset` pair coming from the query string. */
export function parsePagination(limitValue: string | undefined, offsetValue: string | undefined) {
  const limit = limitValue === undefined ? 50 : requiredInt(Number(limitValue), 'Limit', { min: 1, max: 200 })
  const offset = offsetValue === undefined ? 0 : requiredInt(Number(offsetValue), 'Offset', { min: 0, max: 100_000 })
  return { limit, offset }
}

/** Used by the reminder engine to build notification copy. */
export function formatOccurrenceLabel(date: LocalDate): string {
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'long', timeZone: 'UTC' }).format(
    new Date(Date.UTC(date.year, date.month - 1, date.day)),
  )
}

export { photoUrl }
