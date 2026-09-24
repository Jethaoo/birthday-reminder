import { describe, expect, it } from 'vitest'
import { ApiError } from '../src/lib/errors'
import {
  confirmPasswordMatches,
  giftIdeas,
  optionalEmail,
  optionalInt,
  reminderDaysBefore,
  reminderTime,
  requiredEmail,
  requiredPassword,
  requiredString,
  validateBirthdayDate,
} from '../src/lib/validation'

function expectValidationError(run: () => unknown): ApiError {
  try {
    run()
  } catch (error) {
    expect(error).toBeInstanceOf(ApiError)
    const apiError = error as ApiError
    expect(apiError.code).toBe('VALIDATION_ERROR')
    return apiError
  }
  throw new Error('expected a validation error')
}

describe('text validation', () => {
  it('requires a non-empty name and trims it', () => {
    expect(requiredString('  Sarah Tan  ', 'Name')).toBe('Sarah Tan')
    expectValidationError(() => requiredString('   ', 'Name'))
    expectValidationError(() => requiredString(undefined, 'Name'))
    expectValidationError(() => requiredString('x'.repeat(300), 'Name', { max: 120 }))
  })

  it('normalises and validates emails', () => {
    expect(requiredEmail('  SARAH@Example.COM ')).toBe('sarah@example.com')
    expectValidationError(() => requiredEmail('sarah@example'))
    expectValidationError(() => requiredEmail('not-an-email'))
    expect(optionalEmail('')).toBeNull()
    expect(optionalEmail('friend@example.com')).toBe('friend@example.com')
  })
})

describe('password validation', () => {
  it('enforces a minimum length and character mix', () => {
    expect(requiredPassword('Password123')).toBe('Password123')
    expectValidationError(() => requiredPassword('short1'))
    expectValidationError(() => requiredPassword('allletters'))
    expectValidationError(() => requiredPassword('12345678'))
  })

  it('requires matching confirmation', () => {
    expect(() => confirmPasswordMatches('Password123', 'Password123')).not.toThrow()
    expectValidationError(() => confirmPasswordMatches('Password123', 'Password124'))
  })
})

describe('birthday validation', () => {
  it('accepts valid dates including leap day', () => {
    expect(validateBirthdayDate(9, 30)).toEqual({ month: 9, day: 30 })
    expect(validateBirthdayDate(2, 29)).toEqual({ month: 2, day: 29 })
  })

  it('rejects invalid months and days', () => {
    expectValidationError(() => validateBirthdayDate(13, 1))
    expectValidationError(() => validateBirthdayDate(0, 1))
    expectValidationError(() => validateBirthdayDate(4, 31))
    expectValidationError(() => validateBirthdayDate(2, 30))
    expectValidationError(() => validateBirthdayDate(9, 0))
  })

  it('bounds the optional birth year', () => {
    expect(optionalInt(2000, 'Birth year', { min: 1900, max: 2026 })).toBe(2000)
    expect(optionalInt(null, 'Birth year', { min: 1900, max: 2026 })).toBeNull()
    expectValidationError(() => optionalInt(1899, 'Birth year', { min: 1900, max: 2026 }))
    expectValidationError(() => optionalInt(2000.5, 'Birth year', { min: 1900, max: 2026 }))
  })
})

describe('reminder validation', () => {
  it('accepts only the supported reminder periods', () => {
    for (const days of [0, 1, 3, 7, 14, 30]) {
      expect(reminderDaysBefore(days)).toBe(days)
    }
    expectValidationError(() => reminderDaysBefore(2))
    expectValidationError(() => reminderDaysBefore(60))
  })

  it('requires 24-hour times', () => {
    expect(reminderTime('09:00')).toBe('09:00')
    expect(reminderTime('23:59')).toBe('23:59')
    expectValidationError(() => reminderTime('9:00'))
    expectValidationError(() => reminderTime('24:00'))
    expectValidationError(() => reminderTime('09:60'))
  })
})

describe('gift ideas', () => {
  it('accepts a list and defaults to empty', () => {
    expect(giftIdeas(['Perfume', 'Chocolate'])).toEqual(['Perfume', 'Chocolate'])
    expect(giftIdeas(undefined)).toEqual([])
    expectValidationError(() => giftIdeas('Perfume'))
  })
})
