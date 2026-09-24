import type { Context } from 'hono'
import type { ContentfulStatusCode } from 'hono/utils/http-status'

export type ErrorCode =
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'VALIDATION_ERROR'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'RATE_LIMITED'
  | 'PAYLOAD_TOO_LARGE'
  | 'UNSUPPORTED_MEDIA_TYPE'
  | 'SERVER_ERROR'
  | 'NETWORK_ERROR'

const STATUS_BY_CODE: Record<ErrorCode, ContentfulStatusCode> = {
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  VALIDATION_ERROR: 422,
  NOT_FOUND: 404,
  CONFLICT: 409,
  RATE_LIMITED: 429,
  PAYLOAD_TOO_LARGE: 413,
  UNSUPPORTED_MEDIA_TYPE: 415,
  SERVER_ERROR: 500,
  NETWORK_ERROR: 503,
}

/** Every API failure is expressed as this error so responses stay uniform. */
export class ApiError extends Error {
  readonly code: ErrorCode
  readonly status: ContentfulStatusCode
  readonly details?: Record<string, unknown>

  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.status = STATUS_BY_CODE[code]
    this.details = details
  }

  static unauthorized(message = 'Authentication required.') {
    return new ApiError('UNAUTHORIZED', message)
  }

  static forbidden(message = 'You do not have access to this resource.') {
    return new ApiError('FORBIDDEN', message)
  }

  static validation(message: string, details?: Record<string, unknown>) {
    return new ApiError('VALIDATION_ERROR', message, details)
  }

  static notFound(message = 'Resource not found.') {
    return new ApiError('NOT_FOUND', message)
  }

  static conflict(message: string, details?: Record<string, unknown>) {
    return new ApiError('CONFLICT', message, details)
  }

  static rateLimited(message = 'Too many requests. Please try again later.') {
    return new ApiError('RATE_LIMITED', message)
  }

  static server(message = 'Something went wrong.') {
    return new ApiError('SERVER_ERROR', message)
  }
}

export function errorBody(code: ErrorCode, message: string, details?: Record<string, unknown>) {
  return { error: details ? { code, message, details } : { code, message } }
}

export function toErrorResponse(c: Context, error: unknown) {
  if (error instanceof ApiError) {
    return c.json(errorBody(error.code, error.message, error.details), error.status)
  }

  // Unknown failures are logged in full but never leaked to the client.
  console.error('unhandled_error', {
    requestId: c.get('requestId'),
    path: c.req.path,
    error: error instanceof Error ? error.message : String(error),
  })

  return c.json(errorBody('SERVER_ERROR', 'Something went wrong.'), 500)
}
