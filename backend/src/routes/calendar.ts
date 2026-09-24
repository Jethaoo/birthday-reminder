import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { queryInt } from '../lib/route-helpers'
import { calendarSummary } from '../services/birthday-service'
import { localDateTime } from '../lib/time'

const calendar = new Hono<AppEnv>()

calendar.get('/', async (c) => {
  const user = c.get('user')
  const local = localDateTime(new Date(), user.timezone)
  const month = queryInt(c.req.query('month'), 'month', { min: 1, max: 12 }) ?? local.month
  const year = queryInt(c.req.query('year'), 'year', { min: 1900, max: 2200 }) ?? local.year
  return c.json(await calendarSummary(c.env, user, month, year))
})

export default calendar
