import { ApiError } from './errors'
import { isValidMonthDay } from './time'

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/
const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/

export const ALLOWED_REMINDER_DAYS = [0, 1, 3, 7, 14, 30] as const

export function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw ApiError.validation('Request body must be a JSON object.')
  }
  return value as Record<string, unknown>
}

export function requiredString(
  value: unknown,
  field: string,
  { max = 200, min = 1 }: { max?: number; min?: number } = {},
): string {
  if (typeof value !== 'string') throw ApiError.validation(`${field} is required.`, { field })
  const trimmed = value.trim()
  if (trimmed.length < min) throw ApiError.validation(`${field} is required.`, { field })
  if (trimmed.length > max) throw ApiError.validation(`${field} must be ${max} characters or fewer.`, { field })
  return trimmed
}

export function optionalString(
  value: unknown,
  field: string,
  { max = 2000 }: { max?: number } = {},
): string | null {
  if (value === undefined || value === null) return null
  if (typeof value !== 'string') throw ApiError.validation(`${field} must be text.`, { field })
  const trimmed = value.trim()
  if (!trimmed) return null
  if (trimmed.length > max) throw ApiError.validation(`${field} must be ${max} characters or fewer.`, { field })
  return trimmed
}

export function requiredEmail(value: unknown): string {
  const email = requiredString(value, 'Email', { max: 254 }).toLowerCase()
  if (!EMAIL_PATTERN.test(email)) throw ApiError.validation('Enter a valid email address.', { field: 'email' })
  return email
}

export function optionalEmail(value: unknown): string | null {
  const email = optionalString(value, 'Email', { max: 254 })
  if (email === null) return null
  if (!EMAIL_PATTERN.test(email)) throw ApiError.validation('Enter a valid email address.', { field: 'email' })
  return email
}

export function requiredPassword(value: unknown, field = 'Password'): string {
  if (typeof value !== 'string') throw ApiError.validation(`${field} is required.`, { field: 'password' })
  if (value.length < 8) {
    throw ApiError.validation('Password must be at least 8 characters.', { field: 'password' })
  }
  if (value.length > 128) {
    throw ApiError.validation('Password must be 128 characters or fewer.', { field: 'password' })
  }
  if (!/[A-Za-z]/.test(value) || !/\d/.test(value)) {
    throw ApiError.validation('Password must include at least one letter and one number.', {
      field: 'password',
    })
  }
  return value
}

export function confirmPasswordMatches(password: string, confirmation: unknown): void {
  if (typeof confirmation !== 'string' || confirmation !== password) {
    throw ApiError.validation('Passwords do not match.', { field: 'confirmPassword' })
  }
}

export function requiredInt(
  value: unknown,
  field: string,
  { min, max }: { min: number; max: number },
): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw ApiError.validation(`${field} is required.`, { field: field.toLowerCase() })
  }
  if (value < min || value > max) {
    throw ApiError.validation(`${field} must be between ${min} and ${max}.`, { field: field.toLowerCase() })
  }
  return value
}

export function optionalInt(
  value: unknown,
  field: string,
  { min, max }: { min: number; max: number },
): number | null {
  if (value === undefined || value === null || value === '') return null
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw ApiError.validation(`${field} must be a whole number.`, { field: field.toLowerCase() })
  }
  if (value < min || value > max) {
    throw ApiError.validation(`${field} must be between ${min} and ${max}.`, { field: field.toLowerCase() })
  }
  return value
}

export function validateBirthdayDate(month: unknown, day: unknown): { month: number; day: number } {
  const parsedMonth = requiredInt(month, 'Birthday month', { min: 1, max: 12 })
  const parsedDay = requiredInt(day, 'Birthday day', { min: 1, max: 31 })
  if (!isValidMonthDay(parsedMonth, parsedDay)) {
    throw ApiError.validation('Enter a valid birthday date.', { field: 'birthdayDay' })
  }
  return { month: parsedMonth, day: parsedDay }
}

export function reminderTime(value: unknown): string {
  const time = requiredString(value, 'Reminder time', { max: 5 })
  if (!TIME_PATTERN.test(time)) {
    throw ApiError.validation('Reminder time must use 24-hour HH:MM format.', { field: 'reminderTime' })
  }
  return time
}

export function reminderDaysBefore(value: unknown): number {
  const days = requiredInt(value, 'Reminder period', { min: 0, max: 30 })
  if (!(ALLOWED_REMINDER_DAYS as readonly number[]).includes(days)) {
    throw ApiError.validation('Unsupported reminder period.', { field: 'daysBefore' })
  }
  return days
}

export function giftIdeas(value: unknown): string[] {
  if (value === undefined || value === null) return []
  if (!Array.isArray(value)) throw ApiError.validation('Gift ideas must be a list.', { field: 'giftIdeas' })
  if (value.length > 50) {
    throw ApiError.validation('Gift ideas are limited to 50 entries.', { field: 'giftIdeas' })
  }
  return value.map((entry, index) => requiredString(entry, `Gift idea ${index + 1}`, { max: 200 }))
}

export function booleanFlag(value: unknown, field: string): boolean {
  if (typeof value !== 'boolean') throw ApiError.validation(`${field} must be true or false.`, { field })
  return value
}
