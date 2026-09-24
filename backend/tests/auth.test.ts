import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:test'
import { signToken, verifyToken } from '../src/lib/jwt'
import { api, json, registerUser, uniqueEmail, uniqueIp } from './helpers'

interface AuthBody {
  user: { id: string; name: string; email: string; timezone: string }
  accessToken: string
}

describe('registration', () => {
  it('creates an account and returns a token without secrets', async () => {
    const email = uniqueEmail('new')
    const response = await api('POST', '/api/auth/register', {
      body: {
        name: 'Jordan Davis',
        email: `  ${email.toUpperCase()} `,
        password: 'Password123',
        confirmPassword: 'Password123',
        timezone: 'Asia/Kuala_Lumpur',
      },
    })

    expect(response.status).toBe(201)
    const body = await json<AuthBody>(response)
    expect(body.user.email).toBe(email)
    expect(body.user.timezone).toBe('Asia/Kuala_Lumpur')
    expect(body.accessToken.split('.')).toHaveLength(3)
    expect(JSON.stringify(body)).not.toContain('password')
    expect(JSON.stringify(body)).not.toContain('pbkdf2')
  })

  it('stores the password as a PBKDF2 hash, never plaintext', async () => {
    const user = await registerUser()
    const row = await env.DB.prepare('SELECT password_hash FROM users WHERE id = ?')
      .bind(user.id)
      .first<{ password_hash: string }>()
    expect(row?.password_hash.startsWith('pbkdf2$sha256$')).toBe(true)
    expect(row?.password_hash).not.toContain(user.password)
  })

  it('creates default settings for the new account', async () => {
    const user = await registerUser()
    const response = await api('GET', '/api/settings', { token: user.token })
    expect(response.status).toBe(200)
    expect(await json(response)).toMatchObject({
      remindersEnabled: true,
      todayEnabled: true,
      tomorrowEnabled: true,
      soundEnabled: true,
      defaultDaysBefore: 7,
      defaultReminderTime: '09:00',
      themeMode: 'system',
    })
  })

  it('rejects a duplicate email regardless of case', async () => {
    const user = await registerUser()
    const response = await api('POST', '/api/auth/register', {
      body: {
        name: 'Someone Else',
        email: user.email.toUpperCase(),
        password: 'Password123',
        confirmPassword: 'Password123',
        timezone: 'UTC',
      },
    })
    expect(response.status).toBe(409)
    expect(await json<{ error: { code: string } }>(response)).toMatchObject({
      error: { code: 'CONFLICT' },
    })
  })

  it('rejects weak passwords, mismatched confirmation and bad input', async () => {
    const base = {
      name: 'Jordan',
      email: uniqueEmail('weak'),
      password: 'Password123',
      confirmPassword: 'Password123',
      timezone: 'UTC',
    }

    const weak = await api('POST', '/api/auth/register', {
      body: { ...base, password: 'short', confirmPassword: 'short' },
    })
    expect(weak.status).toBe(422)

    const mismatch = await api('POST', '/api/auth/register', {
      body: { ...base, confirmPassword: 'Password124' },
    })
    expect(mismatch.status).toBe(422)

    const badEmail = await api('POST', '/api/auth/register', { body: { ...base, email: 'nope' } })
    expect(badEmail.status).toBe(422)

    const badTimezone = await api('POST', '/api/auth/register', {
      body: { ...base, timezone: 'Mars/Olympus' },
    })
    expect(badTimezone.status).toBe(422)
  })

  it('rejects malformed JSON bodies with a uniform error shape', async () => {
    const response = await api('POST', '/api/auth/register', {
      headers: { 'Content-Type': 'application/json' },
      body: undefined,
      ip: uniqueIp(),
    })
    expect([400, 422]).toContain(response.status)
  })
})

describe('login', () => {
  it('signs an existing user in', async () => {
    const user = await registerUser()
    const response = await api('POST', '/api/auth/login', {
      body: { email: user.email, password: user.password },
    })
    expect(response.status).toBe(200)

    const body = await json<AuthBody>(response)
    expect(body.user.id).toBe(user.id)
    expect(await verifyToken(body.accessToken, env.JWT_SECRET)).not.toBeNull()
  })

  it('rejects a wrong password and an unknown email identically', async () => {
    const user = await registerUser()

    const wrongPassword = await api('POST', '/api/auth/login', {
      body: { email: user.email, password: 'WrongPassword1' },
    })
    const unknownEmail = await api('POST', '/api/auth/login', {
      body: { email: uniqueEmail('ghost'), password: 'Password123' },
    })

    expect(wrongPassword.status).toBe(401)
    expect(unknownEmail.status).toBe(401)
    expect(await json<{ error: { message: string } }>(wrongPassword)).toEqual(
      await json<{ error: { message: string } }>(unknownEmail),
    )
  })

  it('updates the stored timezone when the device reports a new one', async () => {
    const user = await registerUser()
    await api('POST', '/api/auth/login', {
      body: { email: user.email, password: user.password, timezone: 'Europe/London' },
    })

    const row = await env.DB.prepare('SELECT timezone FROM users WHERE id = ?')
      .bind(user.id)
      .first<{ timezone: string }>()
    expect(row?.timezone).toBe('Europe/London')
  })
})

describe('protected routes', () => {
  it('rejects requests without a token', async () => {
    const response = await api('GET', '/api/me')
    expect(response.status).toBe(401)
    expect(await json<{ error: { code: string } }>(response)).toMatchObject({
      error: { code: 'UNAUTHORIZED' },
    })
  })

  it('rejects a forged token', async () => {
    const response = await api('GET', '/api/me', { token: 'a.b.c' })
    expect(response.status).toBe(401)
  })

  it('returns the authenticated user', async () => {
    const user = await registerUser({ name: 'Sarah Tan' })
    const response = await api('GET', '/api/me', { token: user.token })
    expect(response.status).toBe(200)
    expect(await json<{ user: { name: string } }>(response)).toMatchObject({
      user: { name: 'Sarah Tan' },
    })
  })

  it('updates the display name and timezone', async () => {
    const user = await registerUser()
    const response = await api('PATCH', '/api/me', {
      token: user.token,
      body: { name: 'Jordan Davis', timezone: 'Australia/Sydney' },
    })
    expect(response.status).toBe(200)
    expect(await json<{ user: { name: string; timezone: string } }>(response)).toMatchObject({
      user: { name: 'Jordan Davis', timezone: 'Australia/Sydney' },
    })
  })
})

describe('password reset', () => {
  it('accepts a reset request without revealing whether the account exists', async () => {
    const known = await api('POST', '/api/auth/forgot-password', {
      body: { email: (await registerUser()).email },
    })
    const unknown = await api('POST', '/api/auth/forgot-password', {
      body: { email: uniqueEmail('missing') },
    })

    expect(known.status).toBe(202)
    expect(unknown.status).toBe(202)
    expect(await json<{ status: string }>(unknown)).toEqual({ status: 'accepted' })
  })

  it('resets the password and invalidates older tokens', async () => {
    const user = await registerUser()
    const tokenIssuedBefore = await signToken(
      user.id,
      env.JWT_SECRET,
      new Date(Date.now() - 60_000),
    )

    const forgot = await api('POST', '/api/auth/forgot-password', { body: { email: user.email } })
    const { resetToken } = await json<{ resetToken?: string }>(forgot)
    expect(resetToken).toBeTruthy()

    const reset = await api('POST', '/api/auth/reset-password', {
      body: { token: resetToken, password: 'NewPassword123', confirmPassword: 'NewPassword123' },
    })
    expect(reset.status).toBe(200)

    // The previously issued token no longer works.
    expect((await api('GET', '/api/me', { token: tokenIssuedBefore })).status).toBe(401)

    const oldLogin = await api('POST', '/api/auth/login', {
      body: { email: user.email, password: user.password },
    })
    expect(oldLogin.status).toBe(401)

    const newLogin = await api('POST', '/api/auth/login', {
      body: { email: user.email, password: 'NewPassword123' },
    })
    expect(newLogin.status).toBe(200)
  })

  it('refuses a reused or unknown reset token', async () => {
    const user = await registerUser()
    const forgot = await api('POST', '/api/auth/forgot-password', { body: { email: user.email } })
    const { resetToken } = await json<{ resetToken: string }>(forgot)

    await api('POST', '/api/auth/reset-password', {
      body: { token: resetToken, password: 'NewPassword123', confirmPassword: 'NewPassword123' },
    })
    const reused = await api('POST', '/api/auth/reset-password', {
      body: { token: resetToken, password: 'AnotherPass123', confirmPassword: 'AnotherPass123' },
    })
    expect(reused.status).toBe(422)

    const unknown = await api('POST', '/api/auth/reset-password', {
      body: { token: 'not-a-real-token', password: 'AnotherPass123', confirmPassword: 'AnotherPass123' },
    })
    expect(unknown.status).toBe(422)
  })
})

describe('rate limiting', () => {
  it('blocks repeated login attempts from one client', async () => {
    const user = await registerUser()
    const ip = '203.0.113.42'

    const statuses: number[] = []
    for (let attempt = 0; attempt < 6; attempt += 1) {
      const response = await api('POST', '/api/auth/login', {
        ip,
        body: { email: user.email, password: 'WrongPassword1' },
      })
      statuses.push(response.status)
    }

    expect(statuses.slice(0, 5).every((status) => status === 401)).toBe(true)
    expect(statuses[5]).toBe(429)
  })
})

describe('account deletion', () => {
  it('requires the password and removes the account', async () => {
    const user = await registerUser()

    const wrong = await api('DELETE', '/api/me', {
      token: user.token,
      body: { password: 'WrongPassword1' },
    })
    expect(wrong.status).toBe(422)

    const deleted = await api('DELETE', '/api/me', {
      token: user.token,
      body: { password: user.password },
    })
    expect(deleted.status).toBe(200)

    const rows = await env.DB.prepare('SELECT id FROM users WHERE id = ?').bind(user.id).all()
    expect(rows.results).toHaveLength(0)
    expect((await api('GET', '/api/me', { token: user.token })).status).toBe(401)
  })
})
