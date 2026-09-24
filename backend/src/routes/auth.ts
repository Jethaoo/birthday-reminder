import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { RATE_LIMITS } from '../lib/rate-limit'
import { clientKey, enforceRateLimit, readJsonBody } from '../lib/route-helpers'
import {
  loginUser,
  registerUser,
  requestPasswordReset,
  resetPassword,
} from '../services/auth-service'

const auth = new Hono<AppEnv>()

auth.post('/register', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'auth:register', clientKey(c), RATE_LIMITS.auth)
  const result = await registerUser(c.env, body)
  return c.json(result, 201)
})

auth.post('/login', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'auth:login', clientKey(c), RATE_LIMITS.auth)
  const result = await loginUser(c.env, body)
  return c.json(result, 200)
})

/**
 * Tokens are stateless in V1, so logout is a client-side discard. The endpoint
 * exists so the app has a single, auditable sign-out path.
 */
auth.post('/logout', (c) => c.json({ status: 'signed_out' }, 200))

auth.post('/forgot-password', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'auth:forgot', clientKey(c), RATE_LIMITS.passwordReset)
  const resetToken = await requestPasswordReset(c.env, body)
  // Always the same response so accounts cannot be enumerated.
  return c.json(resetToken ? { status: 'accepted', resetToken } : { status: 'accepted' }, 202)
})

auth.post('/reset-password', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'auth:reset', clientKey(c), RATE_LIMITS.passwordReset)
  await resetPassword(c.env, body)
  return c.json({ status: 'password_reset' }, 200)
})

export default auth
