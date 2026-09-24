import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:test'
import { api, json, registerUser } from './helpers'

interface DeviceBody {
  id: string
  platform: string
  deviceName: string | null
  lastSeenAt: string
}

describe('device registration', () => {
  it('registers an FCM token and lists it', async () => {
    const user = await registerUser()
    const response = await api('POST', '/api/devices', {
      token: user.token,
      body: { fcmToken: 'token-abc', platform: 'android', deviceName: 'Pixel 8' },
    })

    expect(response.status).toBe(201)
    expect(await json<DeviceBody>(response)).toMatchObject({
      platform: 'android',
      deviceName: 'Pixel 8',
    })

    const listed = await json<{ items: DeviceBody[] }>(await api('GET', '/api/devices', { token: user.token }))
    expect(listed.items).toHaveLength(1)
  })

  it('refreshes an existing token instead of creating duplicates', async () => {
    const user = await registerUser()
    const first = await json<DeviceBody>(
      await api('POST', '/api/devices', {
        token: user.token,
        body: { fcmToken: 'token-refresh', deviceName: 'Old name' },
      }),
    )
    const second = await api('POST', '/api/devices', {
      token: user.token,
      body: { fcmToken: 'token-refresh', deviceName: 'New name' },
    })

    expect(second.status).toBe(200)
    expect(await json<DeviceBody>(second)).toMatchObject({ id: first.id, deviceName: 'New name' })
    expect((await json<{ items: DeviceBody[] }>(await api('GET', '/api/devices', { token: user.token }))).items)
      .toHaveLength(1)
  })

  it('supports several devices per account', async () => {
    const user = await registerUser()
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'phone-token' } })
    await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'tablet-token' } })

    const listed = await json<{ items: DeviceBody[] }>(await api('GET', '/api/devices', { token: user.token }))
    expect(listed.items).toHaveLength(2)
  })

  it('reassigns a recycled token to the new account', async () => {
    const first = await registerUser()
    const second = await registerUser()

    await api('POST', '/api/devices', { token: first.token, body: { fcmToken: 'shared-token' } })
    const moved = await api('POST', '/api/devices', {
      token: second.token,
      body: { fcmToken: 'shared-token' },
    })
    expect(moved.status).toBe(201)

    const owner = await env.DB.prepare('SELECT user_id FROM devices WHERE fcm_token = ?')
      .bind('shared-token')
      .first<{ user_id: string }>()
    expect(owner?.user_id).toBe(second.id)

    expect(
      (await json<{ items: DeviceBody[] }>(await api('GET', '/api/devices', { token: first.token }))).items,
    ).toHaveLength(0)
  })

  it('rejects an empty token and unregisters on request', async () => {
    const user = await registerUser()
    expect((await api('POST', '/api/devices', { token: user.token, body: { fcmToken: '' } })).status).toBe(422)

    const device = await json<DeviceBody>(
      await api('POST', '/api/devices', { token: user.token, body: { fcmToken: 'to-delete' } }),
    )
    expect((await api('DELETE', `/api/devices/${device.id}`, { token: user.token })).status).toBe(200)
    expect((await api('DELETE', `/api/devices/${device.id}`, { token: user.token })).status).toBe(404)
  })
})
