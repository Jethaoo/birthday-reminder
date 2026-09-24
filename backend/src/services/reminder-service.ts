import type { Env } from '../env'
import { ApiError } from '../lib/errors'
import { newId, nowIso } from '../lib/ids'
import { reminderDaysBefore, reminderTime } from '../lib/validation'
import { toReminderDto, type ReminderDto, type ReminderRow } from '../models'

export interface ReminderInput {
  daysBefore: number
  reminderTime: string
  enabled: boolean
}

export function parseReminderInput(value: unknown, defaults: Partial<ReminderInput> = {}): ReminderInput {
  const input = (typeof value === 'object' && value !== null ? value : {}) as Record<string, unknown>
  const enabled = input.enabled === undefined ? (defaults.enabled ?? true) : input.enabled
  if (typeof enabled !== 'boolean') {
    throw ApiError.validation('Reminder enabled must be true or false.', { field: 'enabled' })
  }

  return {
    daysBefore: reminderDaysBefore(input.daysBefore ?? defaults.daysBefore),
    reminderTime: reminderTime(input.reminderTime ?? defaults.reminderTime),
    enabled,
  }
}

export async function ensureBirthdayOwnership(
  env: Env,
  userId: string,
  birthdayId: string,
): Promise<void> {
  const row = await env.DB.prepare('SELECT id FROM birthdays WHERE id = ? AND user_id = ?')
    .bind(birthdayId, userId)
    .first<{ id: string }>()
  // A missing row and another user's row are indistinguishable to the caller.
  if (!row) throw ApiError.notFound('Birthday not found.')
}

export async function listRemindersForBirthday(
  env: Env,
  userId: string,
  birthdayId: string,
): Promise<ReminderDto[]> {
  await ensureBirthdayOwnership(env, userId, birthdayId)
  const rows = await env.DB.prepare(
    'SELECT * FROM reminders WHERE birthday_id = ? ORDER BY days_before DESC, reminder_time ASC',
  )
    .bind(birthdayId)
    .all<ReminderRow>()
  return rows.results.map(toReminderDto)
}

export async function createReminder(
  env: Env,
  userId: string,
  birthdayId: string,
  body: unknown,
): Promise<ReminderDto> {
  await ensureBirthdayOwnership(env, userId, birthdayId)
  const input = parseReminderInput(body)
  const id = newId()
  const timestamp = nowIso()

  try {
    await env.DB.prepare(
      `INSERT INTO reminders (id, birthday_id, user_id, days_before, reminder_time, enabled, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(id, birthdayId, userId, input.daysBefore, input.reminderTime, input.enabled ? 1 : 0, timestamp, timestamp)
      .run()
  } catch (error) {
    if (isUniqueViolation(error)) {
      throw ApiError.conflict('That reminder already exists for this birthday.')
    }
    throw error
  }

  const row = await env.DB.prepare('SELECT * FROM reminders WHERE id = ?').bind(id).first<ReminderRow>()
  if (!row) throw ApiError.server('Could not save the reminder.')
  return toReminderDto(row)
}

export async function updateReminder(
  env: Env,
  userId: string,
  reminderId: string,
  body: unknown,
): Promise<ReminderDto> {
  const existing = await env.DB.prepare('SELECT * FROM reminders WHERE id = ? AND user_id = ?')
    .bind(reminderId, userId)
    .first<ReminderRow>()
  if (!existing) throw ApiError.notFound('Reminder not found.')

  const input = parseReminderInput(body, {
    daysBefore: existing.days_before,
    reminderTime: existing.reminder_time,
    enabled: existing.enabled === 1,
  })

  try {
    await env.DB.prepare(
      'UPDATE reminders SET days_before = ?, reminder_time = ?, enabled = ?, updated_at = ? WHERE id = ?',
    )
      .bind(input.daysBefore, input.reminderTime, input.enabled ? 1 : 0, nowIso(), reminderId)
      .run()
  } catch (error) {
    if (isUniqueViolation(error)) {
      throw ApiError.conflict('That reminder already exists for this birthday.')
    }
    throw error
  }

  const row = await env.DB.prepare('SELECT * FROM reminders WHERE id = ?').bind(reminderId).first<ReminderRow>()
  if (!row) throw ApiError.server('Could not update the reminder.')
  return toReminderDto(row)
}

export async function deleteReminder(env: Env, userId: string, reminderId: string): Promise<void> {
  const result = await env.DB.prepare('DELETE FROM reminders WHERE id = ? AND user_id = ?')
    .bind(reminderId, userId)
    .run()
  if (result.meta.changes === 0) throw ApiError.notFound('Reminder not found.')
}

/** Replaces the whole reminder set in one call, used by the edit screen. */
export async function replaceReminders(
  env: Env,
  userId: string,
  birthdayId: string,
  value: unknown,
): Promise<ReminderDto[]> {
  if (!Array.isArray(value)) {
    throw ApiError.validation('Reminders must be a list.', { field: 'reminders' })
  }

  const inputs = value.map((entry) => parseReminderInput(entry))
  const dedupe = new Set<string>()
  for (const input of inputs) {
    const key = `${input.daysBefore}:${input.reminderTime}`
    if (dedupe.has(key)) {
      throw ApiError.validation('Two reminders use the same day and time.', { field: 'reminders' })
    }
    dedupe.add(key)
  }

  const statements = [env.DB.prepare('DELETE FROM reminders WHERE birthday_id = ?').bind(birthdayId)]
  const timestamp = nowIso()
  for (const input of inputs) {
    statements.push(
      env.DB.prepare(
        `INSERT INTO reminders (id, birthday_id, user_id, days_before, reminder_time, enabled, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(
        newId(),
        birthdayId,
        userId,
        input.daysBefore,
        input.reminderTime,
        input.enabled ? 1 : 0,
        timestamp,
        timestamp,
      ),
    )
  }

  await env.DB.batch(statements)
  return listRemindersForBirthday(env, userId, birthdayId)
}

export function isUniqueViolation(error: unknown): boolean {
  return error instanceof Error && /UNIQUE constraint failed/i.test(error.message)
}
