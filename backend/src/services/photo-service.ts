import type { Env } from '../env'
import { ApiError } from '../lib/errors'
import { newId } from '../lib/ids'

export const MAX_PHOTO_BYTES = 5 * 1024 * 1024

type SupportedType = 'image/jpeg' | 'image/png' | 'image/webp'

const EXTENSION_BY_TYPE: Record<SupportedType, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

/** Detects the real image type from magic bytes; the upload's claim is ignored. */
export function detectImageType(bytes: Uint8Array): SupportedType | null {
  const startsWith = (...signature: number[]) =>
    signature.every((value, index) => bytes[index] === value)

  if (startsWith(0xff, 0xd8, 0xff)) return 'image/jpeg'
  if (startsWith(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) return 'image/png'
  if (
    startsWith(0x52, 0x49, 0x46, 0x46) &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return 'image/webp'
  }
  return null
}

export function photoKey(userId: string, contentType: SupportedType): string {
  return `photos/${userId}/${newId()}.${EXTENSION_BY_TYPE[contentType]}`
}

/** Photos are private: keys always start with the owning user's prefix. */
export function assertPhotoOwnership(userId: string, key: string): void {
  if (!key.startsWith(`photos/${userId}/`)) {
    throw ApiError.forbidden('You do not have access to this photo.')
  }
}

export async function uploadPhoto(
  env: Env,
  userId: string,
  file: File,
): Promise<{ key: string; url: string; contentType: SupportedType; size: number }> {
  if (file.size > MAX_PHOTO_BYTES) {
    throw new ApiError('PAYLOAD_TOO_LARGE', 'Photos must be 5 MB or smaller.')
  }

  const bytes = new Uint8Array(await file.arrayBuffer())
  const contentType = detectImageType(bytes)
  if (!contentType) {
    throw new ApiError('UNSUPPORTED_MEDIA_TYPE', 'Only JPEG, PNG and WebP images are supported.')
  }

  const key = photoKey(userId, contentType)
  await env.PHOTOS.put(key, bytes, {
    httpMetadata: { contentType },
    customMetadata: { userId },
  })

  return { key, url: photoUrl(key), contentType, size: bytes.byteLength }
}

export async function deletePhoto(env: Env, userId: string, key: string): Promise<void> {
  assertPhotoOwnership(userId, key)
  await env.PHOTOS.delete(key)
  await env.DB.prepare('UPDATE birthdays SET photo_url = NULL WHERE user_id = ? AND photo_url = ?')
    .bind(userId, key)
    .run()
}

export async function readPhoto(
  env: Env,
  userId: string,
  key: string,
): Promise<{ body: ReadableStream; contentType: string } | null> {
  assertPhotoOwnership(userId, key)
  const object = await env.PHOTOS.get(key)
  if (!object) return null
  return {
    body: object.body as ReadableStream,
    contentType: object.httpMetadata?.contentType ?? 'application/octet-stream',
  }
}

/** Relative path stored in D1 and returned to the app. */
export function photoUrl(key: string): string {
  return `/api/photos/${key.replace(/^photos\//, '')}`
}

/** Converts a stored key back into the relative URL handed to clients. */
export function storedPhotoUrl(key: string | null): string | null {
  return key ? photoUrl(key) : null
}

export function keyFromPhotoUrl(url: string): string {
  return url.startsWith('/api/photos/') ? `photos/${url.slice('/api/photos/'.length)}` : url
}
