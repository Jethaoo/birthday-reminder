import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { readJsonBody } from '../lib/route-helpers'
import { getUserSettingsDto, updateUserSettings } from '../services/user-service'

const settings = new Hono<AppEnv>()

settings.get('/', async (c) => c.json(await getUserSettingsDto(c.env, c.get('userId'))))

settings.patch('/', async (c) => {
  const body = await readJsonBody(c)
  return c.json(await updateUserSettings(c.env, c.get('userId'), body))
})

export default settings
