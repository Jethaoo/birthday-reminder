import type { Context } from 'hono'
import type { AppEnv } from '../env'
import { ApiError } from './errors'
import { checkRateLimit, type RateLimitRule } from './rate-limit'

export type AppContext = Context<AppEnv>

/** Best-effort client identity for rate limiting. */
export function clientKey(c: AppContext): string {
  return (
    c.req.header('cf-connecting-ip') ??
    c.req.header('x-forwarded-for')?.split(',')[0]?.trim() ??
    'local'
  )
}

export async function enforceRateLimit(
  c: AppContext,
  bucket: string,
  identifier: string,
  rule: RateLimitRule,
): Promise<void> {
  const result = await checkRateLimit(c.env.DB, `${bucket}:${identifier}`, rule)
  if (!result.allowed) {
    throw new ApiError('RATE_LIMITED', 'Too many requests. Please try again later.', {
      retryAfterSeconds: result.retryAfterSeconds,
    })
  }
}

/** Parses a JSON body, turning malformed input into a validation error. */
export async function readJsonBody(c: AppContext): Promise<unknown> {
  const raw = await c.req.text()
  if (!raw.trim()) return {}
  try {
    return JSON.parse(raw) as unknown
  } catch {
    throw ApiError.validation('Request body must be valid JSON.')
  }
}

export function queryEnum<T extends string>(
  value: string | undefined,
  allowed: readonly T[],
  fallback: T,
  field: string,
): T {
  if (value === undefined || value === '') return fallback
  if (!(allowed as readonly string[]).includes(value)) {
    throw ApiError.validation(`${field} must be one of: ${allowed.join(', ')}.`, { field })
  }
  return value as T
}

export function queryInt(
  value: string | undefined,
  field: string,
  { min, max }: { min: number; max: number },
): number | null {
  if (value === undefined || value === '') return null
  const parsed = Number(value)
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw ApiError.validation(`${field} must be a whole number between ${min} and ${max}.`, { field })
  }
  return parsed
}
