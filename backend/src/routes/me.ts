import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { RATE_LIMITS } from '../lib/rate-limit'
import { enforceRateLimit, readJsonBody } from '../lib/route-helpers'
import { toUserDto } from '../models'
import { changePassword } from '../services/auth-service'
import { deleteAccount, setUserBirthday, updateUser } from '../services/user-service'

const me = new Hono<AppEnv>()

me.get('/', (c) => c.json({ user: toUserDto(c.get('user')) }))

me.patch('/', async (c) => {
  const body = await readJsonBody(c)
  return c.json({ user: await updateUser(c.env, c.get('user'), body) })
})

me.put('/birthday', async (c) => {
  const body = await readJsonBody(c)
  return c.json({ user: await setUserBirthday(c.env, c.get('user'), body) })
})

me.post('/password', async (c) => {
  const body = await readJsonBody(c)
  // Both routes check the current password, so they share the sign-in limit.
  await enforceRateLimit(c, 'auth:password-check', c.get('userId'), RATE_LIMITS.auth)
  await changePassword(c.env, c.get('user'), body)
  return c.json({ status: 'password_changed' })
})

me.delete('/', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'auth:password-check', c.get('userId'), RATE_LIMITS.auth)
  await deleteAccount(c.env, c.get('user'), body)
  return c.json({ status: 'account_deleted' })
})

export default me
