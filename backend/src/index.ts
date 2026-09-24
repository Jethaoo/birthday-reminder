import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { runReminderEngine } from './cron/reminder-engine'
import type { AppEnv } from './env'
import { ApiError, errorBody, toErrorResponse } from './lib/errors'
import { requireAuth } from './middleware/auth'
import authRoutes from './routes/auth'
import birthdaysRoutes, { reminders as reminderRoutes } from './routes/birthdays'
import calendarRoutes from './routes/calendar'
import devRoutes from './routes/dev'
import devicesRoutes from './routes/devices'
import homeRoutes from './routes/home'
import meRoutes from './routes/me'
import photosRoutes from './routes/photos'
import settingsRoutes from './routes/settings'

const app = new Hono<AppEnv>()

app.use('*', async (c, next) => {
  const requestId = c.req.header('cf-ray') ?? crypto.randomUUID()
  c.set('requestId', requestId)

  const startedAt = Date.now()
  await next()

  // Logging deliberately omits bodies, tokens and personal data.
  console.log('request', {
    requestId,
    method: c.req.method,
    path: c.req.path,
    status: c.res.status,
    durationMs: Date.now() - startedAt,
  })
})

app.use(
  '*',
  cors({
    origin: (origin) => origin ?? '*',
    allowHeaders: ['Authorization', 'Content-Type'],
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    maxAge: 86_400,
  }),
)

app.get('/health', (c) => c.json({ status: 'ok', environment: c.env.ENVIRONMENT }))

// Public: registration, sign-in and password reset.
app.route('/api/auth', authRoutes)

// Everything below requires a valid bearer token.
app.use('/api/*', requireAuth)
app.route('/api/me', meRoutes)
app.route('/api/settings', settingsRoutes)
app.route('/api/home', homeRoutes)
app.route('/api/birthdays', birthdaysRoutes)
app.route('/api/reminders', reminderRoutes)
app.route('/api/calendar', calendarRoutes)
app.route('/api/devices', devicesRoutes)
app.route('/api/photos', photosRoutes)
app.route('/api/dev', devRoutes)

app.notFound((c) => c.json(errorBody('NOT_FOUND', 'Endpoint not found.'), 404))

app.onError((error, c) => {
  if (error instanceof ApiError) return toErrorResponse(c, error)
  return toErrorResponse(c, error)
})

export default {
  fetch: app.fetch,
  /** Cron trigger: the reminder engine runs every minute. */
  async scheduled(controller: ScheduledController, env: AppEnv['Bindings'], ctx: ExecutionContext) {
    const now = new Date(controller.scheduledTime ?? Date.now())
    ctx.waitUntil(
      runReminderEngine(env, now).then((summary) => {
        console.log('reminder_engine_run', summary)
      }),
    )
  },
}
