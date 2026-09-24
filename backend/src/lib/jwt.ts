import { base64UrlToBytes, bytesToBase64Url, timingSafeEqual, utf8ToBase64Url } from './crypto'

const encoder = new TextEncoder()
// Long-lived by design: V1 uses a single access token and re-login on expiry.
export const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30

/**
 * A missing secret would otherwise surface as an opaque WebCrypto failure, so
 * it is reported explicitly. `.dev.vars` sets it locally and `wrangler secret
 * put JWT_SECRET` sets it for deployed environments.
 */
function assertSecret(secret: string): void {
  if (!secret || secret.length < 16) {
    throw new Error(
      'JWT_SECRET is missing or too short. Set it in backend/.dev.vars for local development, or with `wrangler secret put JWT_SECRET`.',
    )
  }
}

export interface TokenClaims {
  sub: string
  iat: number
  exp: number
}

function encodeSegment(value: unknown): string {
  return utf8ToBase64Url(JSON.stringify(value))
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, [
    'sign',
    'verify',
  ])
}

export async function signToken(userId: string, secret: string, now = new Date()): Promise<string> {
  assertSecret(secret)
  const issuedAt = Math.floor(now.getTime() / 1000)
  const header = encodeSegment({ alg: 'HS256', typ: 'JWT' })
  const payload = encodeSegment({
    sub: userId,
    iat: issuedAt,
    exp: issuedAt + TOKEN_TTL_SECONDS,
  } satisfies TokenClaims)

  const key = await hmacKey(secret)
  const signature = new Uint8Array(
    await crypto.subtle.sign('HMAC', key, encoder.encode(`${header}.${payload}`)),
  )

  return `${header}.${payload}.${bytesToBase64Url(signature)}`
}

/** Returns the claims when the signature and expiry are valid, otherwise null. */
export async function verifyToken(
  token: string,
  secret: string,
  now = new Date(),
): Promise<TokenClaims | null> {
  assertSecret(secret)
  const parts = token.split('.')
  if (parts.length !== 3) return null

  const [header, payload, signature] = parts as [string, string, string]

  let parsedHeader: { alg?: string }
  let parsedPayload: Partial<TokenClaims>
  try {
    parsedHeader = JSON.parse(new TextDecoder().decode(base64UrlToBytes(header))) as { alg?: string }
    parsedPayload = JSON.parse(new TextDecoder().decode(base64UrlToBytes(payload))) as Partial<TokenClaims>
  } catch {
    return null
  }

  if (parsedHeader.alg !== 'HS256') return null

  const key = await hmacKey(secret)
  const expected = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(`${header}.${payload}`)))
  if (!timingSafeEqual(expected, base64UrlToBytes(signature))) return null

  const { sub, iat, exp } = parsedPayload
  if (typeof sub !== 'string' || typeof iat !== 'number' || typeof exp !== 'number') return null

  const nowSeconds = Math.floor(now.getTime() / 1000)
  if (exp <= nowSeconds) return null
  // Reject tokens issued in the future by more than a minute of clock skew.
  if (iat > nowSeconds + 60) return null

  return { sub, iat, exp }
}
