import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { readJsonBody } from '../lib/route-helpers'
import { toUserDto } from '../models'
import { changePassword } from '../services/auth-service'
import { deleteAccount, updateUser } from '../services/user-service'

const me = new Hono<AppEnv>()

me.get('/', (c) => c.json({ user: toUserDto(c.get('user')) }))

me.patch('/', async (c) => {
  const body = await readJsonBody(c)
  return c.json({ user: await updateUser(c.env, c.get('user'), body) })
})

me.post('/password', async (c) => {
  const body = await readJsonBody(c)
  await changePassword(c.env, c.get('user'), body)
  return c.json({ status: 'password_changed' })
})

me.delete('/', async (c) => {
  const body = await readJsonBody(c)
  await deleteAccount(c.env, c.get('user'), body)
  return c.json({ status: 'account_deleted' })
})

export default me
