import type { MiddlewareHandler } from 'hono'
import type { AppEnv } from '../env'
import { ApiError } from '../lib/errors'
import { verifyToken } from '../lib/jwt'
import { loadUserOrThrow } from '../services/auth-service'

const BEARER_PATTERN = /^Bearer\s+(.+)$/i

/**
 * Resolves the authenticated user from the bearer token. The client can never
 * supply a user id — every protected handler reads it from here.
 */
export const requireAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const header = c.req.header('Authorization') ?? ''
  const match = BEARER_PATTERN.exec(header.trim())
  if (!match?.[1]) {
    throw ApiError.unauthorized('Authentication required.')
  }

  const claims = await verifyToken(match[1], c.env.JWT_SECRET)
  if (!claims) {
    throw ApiError.unauthorized('Your session has expired. Please sign in again.')
  }

  const user = await loadUserOrThrow(c.env, claims.sub)

  // Password resets invalidate older tokens without a server-side session store.
  const passwordChangedAt = Math.floor(new Date(user.password_changed_at).getTime() / 1000)
  if (passwordChangedAt > claims.iat) {
    throw ApiError.unauthorized('Your password changed. Please sign in again.')
  }

  c.set('userId', user.id)
  c.set('user', user)
  await next()
}
