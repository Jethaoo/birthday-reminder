import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { ApiError } from '../lib/errors'
import { newId, nowIso } from '../lib/ids'
import { RATE_LIMITS } from '../lib/rate-limit'
import { asRecord, optionalString, requiredString } from '../lib/validation'
import { enforceRateLimit, readJsonBody } from '../lib/route-helpers'
import { toDeviceDto, type DeviceRow } from '../models'

const devices = new Hono<AppEnv>()

devices.get('/', async (c) => {
  const rows = await c.env.DB.prepare(
    'SELECT * FROM devices WHERE user_id = ? AND active = 1 ORDER BY created_at DESC',
  )
    .bind(c.get('userId'))
    .all<DeviceRow>()
  return c.json({ items: rows.results.map(toDeviceDto) })
})

/** Registers a device, or refreshes the token when the app re-reports it. */
devices.post('/', async (c) => {
  const input = asRecord(await readJsonBody(c))
  const fcmToken = requiredString(input.fcmToken, 'FCM token', { max: 4096 })
  const platform = optionalString(input.platform, 'Platform', { max: 30 }) ?? 'android'
  const deviceName = optionalString(input.deviceName, 'Device name', { max: 120 })
  await enforceRateLimit(c, 'device:write', c.get('userId'), RATE_LIMITS.deviceWrite)

  const timestamp = nowIso()
  const existing = await c.env.DB.prepare('SELECT * FROM devices WHERE fcm_token = ?')
    .bind(fcmToken)
    .first<DeviceRow>()

  if (existing) {
    if (existing.user_id !== c.get('userId')) {
      // A recycled token must not leak another account's notifications.
      await c.env.DB.prepare('DELETE FROM devices WHERE id = ?').bind(existing.id).run()
    } else {
      await c.env.DB.prepare(
        'UPDATE devices SET active = 1, platform = ?, device_name = ?, last_seen_at = ?, updated_at = ? WHERE id = ?',
      )
        .bind(platform, deviceName, timestamp, timestamp, existing.id)
        .run()
      const updated = await c.env.DB.prepare('SELECT * FROM devices WHERE id = ?')
        .bind(existing.id)
        .first<DeviceRow>()
      if (!updated) throw ApiError.server('Could not register the device.')
      return c.json(toDeviceDto(updated), 200)
    }
  }

  const id = newId()
  await c.env.DB.prepare(
    `INSERT INTO devices (id, user_id, fcm_token, platform, device_name, active, last_seen_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)`,
  )
    .bind(id, c.get('userId'), fcmToken, platform, deviceName, timestamp, timestamp, timestamp)
    .run()

  const created = await c.env.DB.prepare('SELECT * FROM devices WHERE id = ?').bind(id).first<DeviceRow>()
  if (!created) throw ApiError.server('Could not register the device.')
  return c.json(toDeviceDto(created), 201)
})

devices.delete('/:id', async (c) => {
  const result = await c.env.DB.prepare('DELETE FROM devices WHERE id = ? AND user_id = ?')
    .bind(c.req.param('id'), c.get('userId'))
    .run()
  if (result.meta.changes === 0) throw ApiError.notFound('Device not found.')
  return c.json({ status: 'deleted' })
})

export default devices
