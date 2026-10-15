import { Hono } from 'hono'
import type { AppEnv } from '../env'
import { ApiError } from '../lib/errors'
import { RATE_LIMITS } from '../lib/rate-limit'
import { enforceRateLimit } from '../lib/route-helpers'
import { deletePhoto, MAX_PHOTO_BYTES, readPhoto, uploadPhoto } from '../services/photo-service'

const photos = new Hono<AppEnv>()

const MULTIPART_OVERHEAD_BYTES = 16 * 1024

photos.post('/', async (c) => {
  await enforceRateLimit(c, 'photo:write', c.get('userId'), RATE_LIMITS.photoWrite)

  // Refuse oversized uploads before the body is buffered. The multipart
  // envelope adds a little on top of the file, hence the small allowance.
  const declaredLength = Number(c.req.header('content-length'))
  if (Number.isFinite(declaredLength) && declaredLength > MAX_PHOTO_BYTES + MULTIPART_OVERHEAD_BYTES) {
    throw new ApiError('PAYLOAD_TOO_LARGE', 'Photos must be 5 MB or smaller.')
  }

  let form: FormData
  try {
    form = await c.req.formData()
  } catch {
    throw ApiError.validation('Upload must be multipart form data.')
  }

  const file = form.get('file')
  if (!file || typeof file === 'string') {
    throw ApiError.validation('Attach an image in the "file" field.', { field: 'file' })
  }

  return c.json(await uploadPhoto(c.env, c.get('userId'), file), 201)
})

// Photos are private, so reads are authenticated and ownership checked.
photos.get('/*', async (c) => {
  const key = c.req.path.replace(/^\/api\/photos\//, '')
  if (!key) throw ApiError.validation('A photo key is required.')

  const photo = await readPhoto(c.env, c.get('userId'), `photos/${key}`)
  if (!photo) throw ApiError.notFound('Photo not found.')

  return new Response(photo.body, {
    headers: {
      'Content-Type': photo.contentType,
      'Cache-Control': 'private, max-age=3600',
      'X-Content-Type-Options': 'nosniff',
    },
  })
})

photos.delete('/*', async (c) => {
  const key = c.req.path.replace(/^\/api\/photos\//, '')
  await deletePhoto(c.env, c.get('userId'), `photos/${key}`)
  return c.json({ status: 'deleted' })
})

export default photos
