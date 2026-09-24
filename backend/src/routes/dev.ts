import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { ApiError } from '../lib/errors'
import { newId, nowIso } from '../lib/ids'
import { readJsonBody } from '../lib/route-helpers'
import { sendPushToUser } from '../services/notification-service'

const dev = new Hono<AppEnv>()

/**
 * Development-only helper that proves push delivery end to end. It is refused
 * in production and never appears in the app's normal flows.
 */
dev.post('/test-notification', async (c) => {
  if (c.env.ENVIRONMENT === 'production') {
    throw ApiError.notFound('Endpoint not found.')
  }

  const body = (await readJsonBody(c)) as { birthdayId?: string; title?: string; body?: string }
  const birthdayId = body.birthdayId ?? null

  const result = await sendPushToUser(c.env, c.get('userId'), {
    title: body.title ?? '🎂 Test notification',
    body: body.body ?? 'If you can see this, push delivery is working.',
    sound: true,
    data: {
      type: 'test',
      birthdayId: birthdayId ?? '',
      route: birthdayId ? `/birthdays/${birthdayId}` : '/',
    },
  })

  await c.env.DB.prepare(
    `INSERT INTO notification_logs (
       id, user_id, birthday_id, reminder_id, device_id, notification_type,
       dedupe_key, scheduled_for, sent_at, status, error_message, created_at
     ) VALUES (?, ?, ?, NULL, NULL, 'test', ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      newId(),
      c.get('userId'),
      birthdayId ?? '00000000-0000-0000-0000-000000000000',
      newId(),
      nowIso(),
      nowIso(),
      result.failed > 0 && result.sent === 0 ? 'failed' : 'sent',
      result.simulated
        ? 'Delivery simulated: FCM credentials are not configured.'
        : result.failed > 0
          ? `FCM rejected the message (${result.reason ?? 'unknown'}).`
          : null,
      nowIso(),
    )
    .run()

  return c.json({
    sent: result.sent,
    failed: result.failed,
    simulated: result.simulated,
    reason: result.reason ?? null,
  })
})

export default dev
