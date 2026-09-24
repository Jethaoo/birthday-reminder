import type { Env } from '../env'
import type { DeviceRow } from '../models'
import { nowIso } from '../lib/ids'

export interface PushMessage {
  title: string
  body: string
  data: Record<string, string>
  sound: boolean
  /** Defaults to the channel implied by `sound`. */
  channelId?: string
}

/**
 * Android 8+ decides sound per channel, so the app registers one channel with
 * sound and one without, and the backend picks per message.
 */
export const NOTIFICATION_CHANNELS = {
  audible: 'birthday_reminders',
  silent: 'birthday_reminders_silent',
} as const

export interface PushResult {
  sent: number
  failed: number
  /** Tokens FCM reported as permanently invalid; they are deactivated. */
  invalidTokens: string[]
  simulated: boolean
}

interface ServiceAccount {
  project_id: string
  client_email: string
  private_key: string
  token_uri?: string
}

interface CachedToken {
  accessToken: string
  expiresAt: number
}

let cachedToken: CachedToken | null = null

function serviceAccount(env: Env): ServiceAccount | null {
  if (!env.FCM_SERVICE_ACCOUNT) return null
  try {
    return JSON.parse(env.FCM_SERVICE_ACCOUNT) as ServiceAccount
  } catch {
    console.error('fcm_service_account_invalid')
    return null
  }
}

function pemToBytes(pem: string): Uint8Array {
  const base64 = pem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i)
  return bytes
}

function base64Url(value: ArrayBuffer | string): string {
  const binary =
    typeof value === 'string'
      ? value
      : Array.from(new Uint8Array(value))
          .map((byte) => String.fromCharCode(byte))
          .join('')
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/** Exchanges the service account for an OAuth2 access token, cached in memory. */
async function accessToken(env: Env): Promise<string | null> {
  const account = serviceAccount(env)
  if (!account) return null

  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.accessToken

  const tokenUri = account.token_uri ?? 'https://oauth2.googleapis.com/token'
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    }),
  )

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  )

  const assertion = `${header}.${claims}.${base64Url(signature)}`
  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  if (!response.ok) {
    console.error('fcm_token_exchange_failed', { status: response.status })
    return null
  }

  const payload = (await response.json()) as { access_token?: string; expires_in?: number }
  if (!payload.access_token) return null

  cachedToken = {
    accessToken: payload.access_token,
    expiresAt: now + (payload.expires_in ?? 3600),
  }
  return cachedToken.accessToken
}

/** Sends a push to every active device the user owns. */
export async function sendPushToUser(env: Env, userId: string, message: PushMessage): Promise<PushResult> {
  const devices = await env.DB.prepare('SELECT * FROM devices WHERE user_id = ? AND active = 1')
    .bind(userId)
    .all<DeviceRow>()

  const result: PushResult = { sent: 0, failed: 0, invalidTokens: [], simulated: false }
  if (devices.results.length === 0) return result

  const account = serviceAccount(env)
  const token = account ? await accessToken(env) : null

  // Without credentials the engine still records the notification so local
  // development and tests exercise the full scheduling path.
  //
  // Automated tests never contact Google: `.dev.vars` is loaded by the vitest
  // Workers pool, so credentials can be present during a test run.
  if (env.ENVIRONMENT === 'test' || !account || !token) {
    result.simulated = true
    result.sent = devices.results.length
    return result
  }

  for (const device of devices.results) {
    const channelId =
      message.channelId ?? (message.sound ? NOTIFICATION_CHANNELS.audible : NOTIFICATION_CHANNELS.silent)

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: device.fcm_token,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: channelId,
                sound: channelId === NOTIFICATION_CHANNELS.audible ? 'default' : undefined,
              },
            },
          },
        }),
      },
    )

    if (response.ok) {
      result.sent += 1
      continue
    }

    const errorBody = await response.text()
    result.failed += 1

    // The reason is logged; the body is not, because FCM echoes the token back.
    let reason = 'UNKNOWN'
    try {
      const parsed = JSON.parse(errorBody) as { error?: { status?: string } }
      reason = parsed.error?.status ?? reason
    } catch {
      // Non-JSON error bodies keep the default reason.
    }
    console.error('fcm_send_failed', { status: response.status, deviceId: device.id, reason })

    if (response.status === 404 || /UNREGISTERED|INVALID_ARGUMENT/.test(errorBody)) {
      result.invalidTokens.push(device.fcm_token)
      await env.DB.prepare('UPDATE devices SET active = 0, updated_at = ? WHERE id = ?')
        .bind(nowIso(), device.id)
        .run()
    }
  }

  return result
}
