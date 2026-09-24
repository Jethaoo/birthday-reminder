import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { RATE_LIMITS } from '../lib/rate-limit'
import { enforceRateLimit, queryEnum, queryInt, readJsonBody } from '../lib/route-helpers'
import {
  createBirthday,
  deleteBirthday,
  getBirthday,
  listBirthdays,
  parsePagination,
  updateBirthday,
  type BirthdayFilter,
  type BirthdaySort,
} from '../services/birthday-service'
import {
  createReminder,
  deleteReminder,
  listRemindersForBirthday,
  updateReminder,
} from '../services/reminder-service'

const FILTERS: readonly BirthdayFilter[] = [
  'all',
  'today',
  'this_week',
  'this_month',
  'family',
  'friend',
  'colleague',
  'other',
]

const SORTS: readonly BirthdaySort[] = ['upcoming', 'name', 'recently_added']

const birthdays = new Hono<AppEnv>()

birthdays.get('/', async (c) => {
  const { limit, offset } = parsePagination(c.req.query('limit'), c.req.query('offset'))
  const result = await listBirthdays(c.env, c.get('user'), {
    search: c.req.query('search')?.trim() || null,
    filter: queryEnum(c.req.query('filter'), FILTERS, 'all', 'filter'),
    sort: queryEnum(c.req.query('sort'), SORTS, 'upcoming', 'sort'),
    month: queryInt(c.req.query('month'), 'month', { min: 1, max: 12 }),
    year: queryInt(c.req.query('year'), 'year', { min: 1900, max: 2200 }),
    date: c.req.query('date') ?? null,
    limit,
    offset,
  })
  return c.json(result)
})

birthdays.post('/', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'birthday:write', c.get('userId'), RATE_LIMITS.birthdayWrite)
  return c.json(await createBirthday(c.env, c.get('user'), body), 201)
})

birthdays.get('/:id', async (c) => c.json(await getBirthday(c.env, c.get('user'), c.req.param('id'))))

birthdays.put('/:id', async (c) => {
  const body = await readJsonBody(c)
  await enforceRateLimit(c, 'birthday:write', c.get('userId'), RATE_LIMITS.birthdayWrite)
  return c.json(await updateBirthday(c.env, c.get('user'), c.req.param('id'), body))
})

birthdays.delete('/:id', async (c) => {
  await deleteBirthday(c.env, c.get('user'), c.req.param('id'))
  return c.json({ status: 'deleted' })
})

birthdays.get('/:id/reminders', async (c) =>
  c.json({ items: await listRemindersForBirthday(c.env, c.get('userId'), c.req.param('id')) }),
)

birthdays.post('/:id/reminders', async (c) => {
  const body = await readJsonBody(c)
  const reminder = await createReminder(c.env, c.get('userId'), c.req.param('id'), body)
  return c.json(reminder, 201)
})

// Standalone reminder routes keep the list screen simple: it can edit or delete
// a reminder without loading the parent birthday first.
export const reminders = new Hono<AppEnv>()

reminders.patch('/:id', async (c) => {
  const body = await readJsonBody(c)
  return c.json(await updateReminder(c.env, c.get('userId'), c.req.param('id'), body))
})

reminders.delete('/:id', async (c) => {
  await deleteReminder(c.env, c.get('userId'), c.req.param('id'))
  return c.json({ status: 'deleted' })
})

export default birthdays
