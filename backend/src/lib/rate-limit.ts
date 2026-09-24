/**
 * Fixed-window rate limiting backed by D1.
 *
 * A D1 counter is used instead of the Workers Rate Limiting binding so the
 * behaviour is identical under `wrangler dev`, in the vitest Workers pool and
 * in production, and so limits can be asserted in tests.
 */
export interface RateLimitRule {
  /** Number of allowed requests per window. */
  limit: number
  /** Window length in seconds. */
  windowSeconds: number
}

export interface RateLimitResult {
  allowed: boolean
  remaining: number
  retryAfterSeconds: number
}

export async function checkRateLimit(
  db: D1Database,
  key: string,
  rule: RateLimitRule,
  now = new Date(),
): Promise<RateLimitResult> {
  const windowStart = Math.floor(now.getTime() / (rule.windowSeconds * 1000)) * rule.windowSeconds

  await db
    .prepare(
      `INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 1)
       ON CONFLICT (key) DO UPDATE SET
         count = CASE WHEN window_start = excluded.window_start THEN count + 1 ELSE 1 END,
         window_start = excluded.window_start`,
    )
    .bind(key, windowStart)
    .run()

  const row = await db.prepare('SELECT window_start, count FROM rate_limits WHERE key = ?').bind(key).first<{
    window_start: number
    count: number
  }>()

  const count = row?.count ?? 1
  const currentWindowStart = row?.window_start ?? windowStart

  return {
    allowed: count <= rule.limit,
    remaining: Math.max(0, rule.limit - count),
    retryAfterSeconds: Math.max(1, currentWindowStart + rule.windowSeconds - Math.floor(now.getTime() / 1000)),
  }
}

export const RATE_LIMITS = {
  auth: { limit: 5, windowSeconds: 600 },
  passwordReset: { limit: 5, windowSeconds: 600 },
  birthdayWrite: { limit: 60, windowSeconds: 3600 },
  deviceWrite: { limit: 20, windowSeconds: 3600 },
  photoWrite: { limit: 30, windowSeconds: 3600 },
} as const satisfies Record<string, RateLimitRule>
