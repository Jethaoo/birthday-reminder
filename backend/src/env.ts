import type { UserRow } from './models'

/** Bindings and secrets available to the Worker. */
export interface Env {
  DB: D1Database
  PHOTOS: R2Bucket
  ENVIRONMENT: string
  APP_BASE_URL: string
  JWT_SECRET: string
  /** Service-account JSON for FCM HTTP v1. Absent in tests and local dev. */
  FCM_SERVICE_ACCOUNT?: string
  RESEND_API_KEY?: string
  EMAIL_FROM?: string
  TEST_MIGRATIONS?: unknown
}

export interface RequestContext {
  userId: string
  requestId: string
  user: UserRow
}

export type AppEnv = {
  Bindings: Env
  Variables: RequestContext
}

export function isProduction(env: Env): boolean {
  return env.ENVIRONMENT === 'production'
}
