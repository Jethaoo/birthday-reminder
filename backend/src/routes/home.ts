import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { homeSummary } from '../services/birthday-service'

const home = new Hono<AppEnv>()

home.get('/', async (c) => c.json(await homeSummary(c.env, c.get('user'))))

export default home
