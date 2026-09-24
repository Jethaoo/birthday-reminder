import { describe, expect, it } from 'vitest'
import { signToken, verifyToken } from '../src/lib/jwt'
import { hashPassword, sha256Hex, verifyPassword } from '../src/lib/crypto'

const SECRET = 'test-secret'

function base64UrlJson(value: unknown): string {
  return btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

describe('jwt', () => {
  it('signs and verifies a token', async () => {
    const token = await signToken('user-1', SECRET)
    const claims = await verifyToken(token, SECRET)
    expect(claims?.sub).toBe('user-1')
    expect(claims?.exp).toBeGreaterThan(claims?.iat ?? 0)
  })

  it('rejects a token signed with another secret', async () => {
    const token = await signToken('user-1', 'other-secret')
    expect(await verifyToken(token, SECRET)).toBeNull()
  })

  it('rejects a tampered payload', async () => {
    const token = await signToken('user-1', SECRET)
    const [header, , signature] = token.split('.')
    const forged = base64UrlJson({ sub: 'user-2', iat: 1, exp: 9_999_999_999 })
    expect(await verifyToken(`${header}.${forged}.${signature}`, SECRET)).toBeNull()
  })

  it('rejects an expired token', async () => {
    const token = await signToken('user-1', SECRET, new Date('2020-01-01T00:00:00Z'))
    expect(await verifyToken(token, SECRET, new Date('2026-01-01T00:00:00Z'))).toBeNull()
  })

  it('rejects malformed input', async () => {
    expect(await verifyToken('not.a.token', SECRET)).toBeNull()
    expect(await verifyToken('', SECRET)).toBeNull()
  })
})

describe('password hashing', () => {
  it('hashes and verifies without keeping the plaintext', async () => {
    const hash = await hashPassword('Password123')
    expect(hash.startsWith('pbkdf2$sha256$')).toBe(true)
    expect(hash).not.toContain('Password123')
    expect(await verifyPassword('Password123', hash)).toBe(true)
    expect(await verifyPassword('Password124', hash)).toBe(false)
  })

  it('uses a different salt every time', async () => {
    expect(await hashPassword('Password123')).not.toBe(await hashPassword('Password123'))
  })

  it('rejects malformed stored hashes', async () => {
    expect(await verifyPassword('Password123', 'plaintext')).toBe(false)
  })
})

describe('dedupe hashing', () => {
  it('is stable and distinct per input', async () => {
    const a = await sha256Hex('user|birthday|reminder|2026-09-30|birthday_advance')
    const b = await sha256Hex('user|birthday|reminder|2026-09-30|birthday_advance')
    const c = await sha256Hex('user|birthday|reminder|2026-09-30|birthday_today')
    expect(a).toBe(b)
    expect(a).not.toBe(c)
  })
})
