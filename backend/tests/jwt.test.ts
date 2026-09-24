import { describe, expect, it } from 'vitest'
import { signToken, verifyToken } from '../src/lib/jwt'
import { hashPassword, sha256Hex, verifyPassword } from '../src/lib/crypto'

const SECRET = 'test-secret-that-is-long-enough'
const OTHER_SECRET = 'other-secret-that-is-long-enough'

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
    const token = await signToken('user-1', OTHER_SECRET)
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

  it('refuses to sign with a missing or weak secret', async () => {
    await expect(signToken('user-1', '')).rejects.toThrow(/JWT_SECRET/)
    await expect(signToken('user-1', 'too-short')).rejects.toThrow(/JWT_SECRET/)
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

  it('stays within the platform PBKDF2 iteration cap', async () => {
    // Cloudflare rejects anything above 100,000 iterations at runtime, which
    // local workerd does not, so this guards an environment-only failure.
    const hash = await hashPassword('Password123')
    const iterations = Number(hash.split('$')[2])

    expect(iterations).toBeLessThanOrEqual(100_000)
    expect(iterations).toBeGreaterThanOrEqual(100_000)
  })

  it('still verifies hashes made with a higher iteration count', async () => {
    // Hashes written before the cap was applied record their own count.
    const legacy = 'pbkdf2$sha256$100000$'
    const fresh = await hashPassword('Password123')
    const [, , , salt, digest] = fresh.split('$')

    expect(await verifyPassword('Password123', `${legacy}${salt}$${digest}`)).toBe(true)
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
