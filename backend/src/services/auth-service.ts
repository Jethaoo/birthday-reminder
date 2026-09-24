import type { Env } from '../env'
import { hashPassword, randomToken, sha256Hex, verifyPassword } from '../lib/crypto'
import { ApiError } from '../lib/errors'
import { newId, nowIso } from '../lib/ids'
import { signToken } from '../lib/jwt'
import { isValidTimeZone } from '../lib/time'
import {
  asRecord,
  confirmPasswordMatches,
  optionalString,
  requiredEmail,
  requiredPassword,
  requiredString,
} from '../lib/validation'
import { toUserDto, type UserDto, type UserRow } from '../models'
import { emailSender, passwordResetEmail } from './email-service'

export interface AuthResult {
  user: UserDto
  accessToken: string
}

const RESET_TOKEN_TTL_MINUTES = 60

export async function loadUserOrThrow(env: Env, userId: string): Promise<UserRow> {
  const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>()
  if (!user) throw ApiError.unauthorized('Your session is no longer valid. Please sign in again.')
  return user
}

function timezoneFrom(value: unknown, fallback = 'UTC'): string {
  const timezone = optionalString(value, 'Timezone', { max: 64 })
  if (timezone === null) return fallback
  if (!isValidTimeZone(timezone)) {
    throw ApiError.validation('Timezone must be a valid IANA timezone.', { field: 'timezone' })
  }
  return timezone
}

export async function registerUser(env: Env, body: unknown): Promise<AuthResult> {
  const input = asRecord(body)
  const name = requiredString(input.name, 'Name', { max: 120 })
  const email = requiredEmail(input.email)
  const password = requiredPassword(input.password)
  confirmPasswordMatches(password, input.confirmPassword)
  const timezone = timezoneFrom(input.timezone)

  const existing = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first<{
    id: string
  }>()
  if (existing) {
    throw ApiError.conflict('An account with this email already exists.')
  }

  const id = newId()
  const timestamp = nowIso()
  const passwordHash = await hashPassword(password)

  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO users (id, email, password_hash, display_name, timezone, password_changed_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(id, email, passwordHash, name, timezone, timestamp, timestamp, timestamp),
    env.DB.prepare(
      `INSERT INTO user_settings (user_id, updated_at) VALUES (?, ?)`,
    ).bind(id, timestamp),
  ])

  const user = await loadUserOrThrow(env, id)
  return { user: toUserDto(user), accessToken: await signToken(id, env.JWT_SECRET) }
}

export async function loginUser(env: Env, body: unknown): Promise<AuthResult> {
  const input = asRecord(body)
  const email = requiredEmail(input.email)
  const password = typeof input.password === 'string' ? input.password : ''

  const user = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first<UserRow>()
  // The same message is returned for unknown emails and wrong passwords.
  if (!user || !(await verifyPassword(password, user.password_hash))) {
    throw ApiError.unauthorized('Incorrect email or password.')
  }

  // The app reports its timezone on sign-in so travellers stay on local time.
  const timezone = timezoneFrom(input.timezone, user.timezone)
  if (timezone !== user.timezone) {
    await env.DB.prepare('UPDATE users SET timezone = ?, updated_at = ? WHERE id = ?')
      .bind(timezone, nowIso(), user.id)
      .run()
  }

  return {
    user: toUserDto({ ...user, timezone }),
    accessToken: await signToken(user.id, env.JWT_SECRET),
  }
}

/**
 * Always resolves without revealing whether the email exists. The reset link is
 * emailed when the account is real; otherwise the request is silently ignored.
 *
 * Outside production the plaintext token is also returned so automated tests and
 * local development can complete the flow without an inbox. Production never
 * returns it.
 */
export async function requestPasswordReset(env: Env, body: unknown): Promise<string | null> {
  const input = asRecord(body)
  const email = requiredEmail(input.email)

  const user = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first<UserRow>()
  if (!user) return null

  const token = randomToken()
  const tokenHash = await sha256Hex(token)
  const createdAt = new Date()
  const expiresAt = new Date(createdAt.getTime() + RESET_TOKEN_TTL_MINUTES * 60_000)

  await env.DB.batch([
    env.DB.prepare('DELETE FROM password_reset_tokens WHERE user_id = ? AND used_at IS NULL')
      .bind(user.id),
    env.DB.prepare(
      `INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at, used_at, created_at)
       VALUES (?, ?, ?, ?, NULL, ?)`,
    ).bind(newId(), user.id, tokenHash, expiresAt.toISOString(), createdAt.toISOString()),
  ])

  const resetUrl = `${env.APP_BASE_URL.replace(/\/$/, '')}/reset-password?token=${encodeURIComponent(token)}`
  await emailSender(env).send({
    to: user.email,
    subject: 'Reset your Birthday Reminder password',
    html: passwordResetEmail(resetUrl, user.display_name),
    text: `Reset your password: ${resetUrl} (expires in ${RESET_TOKEN_TTL_MINUTES} minutes)`,
  })

  return env.ENVIRONMENT === 'production' ? null : token
}

export async function resetPassword(env: Env, body: unknown): Promise<void> {
  const input = asRecord(body)
  const token = requiredString(input.token, 'Reset token', { max: 200 })
  const password = requiredPassword(input.password)
  confirmPasswordMatches(password, input.confirmPassword)

  const tokenHash = await sha256Hex(token)
  const record = await env.DB.prepare(
    'SELECT id, user_id, expires_at, used_at FROM password_reset_tokens WHERE token_hash = ?',
  )
    .bind(tokenHash)
    .first<{ id: string; user_id: string; expires_at: string; used_at: string | null }>()

  if (!record || record.used_at !== null) {
    throw ApiError.validation('This reset link is no longer valid. Request a new one.', {
      field: 'token',
    })
  }
  if (new Date(record.expires_at).getTime() <= Date.now()) {
    throw ApiError.validation('This reset link has expired. Request a new one.', { field: 'token' })
  }

  const timestamp = nowIso()
  const passwordHash = await hashPassword(password)

  await env.DB.batch([
    env.DB.prepare('UPDATE users SET password_hash = ?, password_changed_at = ?, updated_at = ? WHERE id = ?')
      .bind(passwordHash, timestamp, timestamp, record.user_id),
    env.DB.prepare('UPDATE password_reset_tokens SET used_at = ? WHERE id = ?').bind(timestamp, record.id),
    env.DB.prepare('DELETE FROM password_reset_tokens WHERE user_id = ? AND used_at IS NULL').bind(
      record.user_id,
    ),
  ])
}

export async function changePassword(
  env: Env,
  user: UserRow,
  body: unknown,
): Promise<void> {
  const input = asRecord(body)
  const currentPassword = typeof input.currentPassword === 'string' ? input.currentPassword : ''
  if (!(await verifyPassword(currentPassword, user.password_hash))) {
    throw ApiError.validation('Your current password is incorrect.', { field: 'currentPassword' })
  }

  const password = requiredPassword(input.newPassword, 'New password')
  confirmPasswordMatches(password, input.confirmPassword)

  const timestamp = nowIso()
  await env.DB.prepare('UPDATE users SET password_hash = ?, password_changed_at = ?, updated_at = ? WHERE id = ?')
    .bind(await hashPassword(password), timestamp, timestamp, user.id)
    .run()
}
