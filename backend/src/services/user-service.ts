import type { Env } from '../env'
import { verifyPassword } from '../lib/crypto'
import { ApiError } from '../lib/errors'
import { nowIso } from '../lib/ids'
import { isLeapYear, isValidTimeZone } from '../lib/time'
import {
  asRecord,
  booleanFlag,
  optionalInt,
  optionalString,
  reminderDaysBefore,
  reminderTime,
  requiredString,
  validateBirthdayDate,
} from '../lib/validation'
import {
  toUserDto,
  toUserSettingsDto,
  type UserDto,
  type UserRow,
  type UserSettingsDto,
  type UserSettingsRow,
} from '../models'
import { assertPhotoOwnership, deletePhotoIfUnused, keyFromPhotoUrl } from './photo-service'

const MIN_BIRTH_YEAR = 1900

export async function getUserSettings(env: Env, userId: string): Promise<UserSettingsRow> {
  const settings = await env.DB.prepare('SELECT * FROM user_settings WHERE user_id = ?')
    .bind(userId)
    .first<UserSettingsRow>()
  if (settings) return settings

  // Accounts created before the settings row existed still get defaults.
  const timestamp = nowIso()
  await env.DB.prepare('INSERT OR IGNORE INTO user_settings (user_id, updated_at) VALUES (?, ?)')
    .bind(userId, timestamp)
    .run()
  const created = await env.DB.prepare('SELECT * FROM user_settings WHERE user_id = ?')
    .bind(userId)
    .first<UserSettingsRow>()
  if (!created) throw ApiError.server('Could not load notification settings.')
  return created
}

export async function updateUser(env: Env, user: UserRow, body: unknown): Promise<UserDto> {
  const input = asRecord(body)
  const updates: string[] = []
  const values: unknown[] = []
  const previousPhotoKey = user.photo_url

  if (input.name !== undefined) {
    updates.push('display_name = ?')
    values.push(requiredString(input.name, 'Name', { max: 120 }))
  }

  if (input.timezone !== undefined) {
    const timezone = requiredString(input.timezone, 'Timezone', { max: 64 })
    if (!isValidTimeZone(timezone)) {
      throw ApiError.validation('Timezone must be a valid IANA timezone.', { field: 'timezone' })
    }
    updates.push('timezone = ?')
    values.push(timezone)
  }

  if (input.photoUrl !== undefined) {
    const photo = optionalString(input.photoUrl, 'Profile photo', { max: 300 })
    if (photo === null) {
      updates.push('photo_url = NULL')
    } else {
      const key = keyFromPhotoUrl(photo)
      assertPhotoOwnership(user.id, key)
      if (!(await env.PHOTOS.head(key))) {
        throw ApiError.validation('That profile photo no longer exists.', { field: 'photoUrl' })
      }
      updates.push('photo_url = ?')
      values.push(key)
    }
  }

  if (updates.length === 0) {
    throw ApiError.validation('Nothing to update.', { field: 'body' })
  }

  updates.push('updated_at = ?')
  values.push(nowIso(), user.id)

  await env.DB.prepare(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`)
    .bind(...values)
    .run()

  const updated = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(user.id).first<UserRow>()
  if (!updated) throw ApiError.server('Could not update the account.')

  // Replace/remove the old object only after the account now points elsewhere and
  // neither the profile nor a birthday references it.
  if (previousPhotoKey && previousPhotoKey !== updated.photo_url) {
    await deletePhotoIfUnused(env, user.id, previousPhotoKey)
  }
  return toUserDto(updated)
}

/** Sets the signed-in user's own birthday exactly once. */
export async function setUserBirthday(env: Env, user: UserRow, body: unknown): Promise<UserDto> {
  if (user.birthday_month !== null) {
    throw ApiError.conflict('Your birthday has already been set and cannot be changed.')
  }

  const input = asRecord(body)
  const { month, day } = validateBirthdayDate(input.birthdayMonth, input.birthdayDay)
  const currentYear = new Date().getUTCFullYear()
  const birthYear = optionalInt(input.birthYear, 'Birth year', {
    min: MIN_BIRTH_YEAR,
    max: currentYear,
  })

  if (month === 2 && day === 29 && birthYear !== null && !isLeapYear(birthYear)) {
    throw ApiError.validation(`${birthYear} was not a leap year, so it has no 29 February.`, {
      field: 'birthYear',
    })
  }

  const timestamp = nowIso()
  const result = await env.DB.prepare(
    `UPDATE users
     SET birthday_month = ?, birthday_day = ?, birth_year = ?, updated_at = ?
     WHERE id = ? AND birthday_month IS NULL`,
  )
    .bind(month, day, birthYear, timestamp, user.id)
    .run()

  if (result.meta.changes !== 1) {
    throw ApiError.conflict('Your birthday has already been set and cannot be changed.')
  }

  const updated = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(user.id).first<UserRow>()
  if (!updated) throw ApiError.server('Could not update your birthday.')
  return toUserDto(updated)
}

export async function getUserSettingsDto(env: Env, userId: string): Promise<UserSettingsDto> {
  return toUserSettingsDto(await getUserSettings(env, userId))
}

export async function updateUserSettings(env: Env, userId: string, body: unknown): Promise<UserSettingsDto> {
  const input = asRecord(body)
  const updates: string[] = []
  const values: unknown[] = []

  const flags: Array<[keyof UserSettingsDto, string]> = [
    ['remindersEnabled', 'reminders_enabled'],
    ['todayEnabled', 'today_enabled'],
    ['tomorrowEnabled', 'tomorrow_enabled'],
    ['soundEnabled', 'sound_enabled'],
  ]

  for (const [field, column] of flags) {
    if (input[field] !== undefined) {
      updates.push(`${column} = ?`)
      values.push(booleanFlag(input[field], field) ? 1 : 0)
    }
  }

  if (input.defaultDaysBefore !== undefined) {
    updates.push('default_days_before = ?')
    values.push(reminderDaysBefore(input.defaultDaysBefore))
  }

  if (input.defaultReminderTime !== undefined) {
    updates.push('default_reminder_time = ?')
    values.push(reminderTime(input.defaultReminderTime))
  }

  if (input.themeMode !== undefined) {
    const theme = requiredString(input.themeMode, 'Theme', { max: 10 })
    if (!['system', 'light', 'dark'].includes(theme)) {
      throw ApiError.validation('Theme must be system, light or dark.', { field: 'themeMode' })
    }
    updates.push('theme_mode = ?')
    values.push(theme)
  }

  if (updates.length === 0) {
    throw ApiError.validation('Nothing to update.', { field: 'body' })
  }

  await getUserSettings(env, userId)
  updates.push('updated_at = ?')
  values.push(nowIso(), userId)

  await env.DB.prepare(`UPDATE user_settings SET ${updates.join(', ')} WHERE user_id = ?`)
    .bind(...values)
    .run()

  return getUserSettingsDto(env, userId)
}

/**
 * Deletes the account and everything owned by it. Photos are removed from R2
 * first because object storage is not covered by D1 cascades.
 */
export async function deleteAccount(env: Env, user: UserRow, body: unknown): Promise<void> {
  const input = asRecord(body)
  const password = typeof input.password === 'string' ? input.password : ''
  if (!(await verifyPassword(password, user.password_hash))) {
    throw ApiError.validation('Enter your password to confirm.', { field: 'password' })
  }

  await deleteUserPhotos(env, user.id)

  await env.DB.batch([
    env.DB.prepare('DELETE FROM notification_logs WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM reminders WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM birthdays WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM devices WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM password_reset_tokens WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM user_settings WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM users WHERE id = ?').bind(user.id),
  ])
}

async function deleteUserPhotos(env: Env, userId: string): Promise<void> {
  const prefix = `photos/${userId}/`
  let cursor: string | undefined

  do {
    const listing = await env.PHOTOS.list({ prefix, cursor, limit: 100 })
    if (listing.objects.length > 0) {
      await env.PHOTOS.delete(listing.objects.map((object) => object.key))
    }
    cursor = listing.truncated ? listing.cursor : undefined
  } while (cursor)
}
