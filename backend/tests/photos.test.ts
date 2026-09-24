import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:test'
import { api, createBirthday, json, registerUser } from './helpers'

const PNG_BYTES = new Uint8Array([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
])

function photoForm(bytes: Uint8Array = PNG_BYTES, name = 'birthday.png', type = 'image/png'): FormData {
  const form = new FormData()
  form.append('file', new File([bytes], name, { type }))
  return form
}

interface UploadBody {
  key: string
  url: string
  contentType: string
  size: number
}

describe('photo upload', () => {
  it('stores a validated image and returns a private path', async () => {
    const user = await registerUser()
    const response = await api('POST', '/api/photos', { token: user.token, formData: photoForm() })

    expect(response.status).toBe(201)
    const body = await json<UploadBody>(response)
    expect(body.contentType).toBe('image/png')
    expect(body.key.startsWith(`photos/${user.id}/`)).toBe(true)
    expect(body.url).toBe(`/api/photos/${user.id}/${body.key.split('/').pop()}`)
    expect(body.size).toBe(PNG_BYTES.byteLength)
  })

  it('serves the photo back only to its owner', async () => {
    const owner = await registerUser()
    const stranger = await registerUser()
    const body = await json<UploadBody>(
      await api('POST', '/api/photos', { token: owner.token, formData: photoForm() }),
    )

    const mine = await api('GET', body.url, { token: owner.token })
    expect(mine.status).toBe(200)
    expect(mine.headers.get('content-type')).toBe('image/png')
    // The body must be drained so the R2 blob is released on Windows.
    expect((await mine.arrayBuffer()).byteLength).toBe(PNG_BYTES.byteLength)

    const theirs = await api('GET', body.url, { token: stranger.token })
    expect(theirs.status).toBe(403)
    await theirs.arrayBuffer()
  })

  it('rejects files that are not real images and oversized uploads', async () => {
    const user = await registerUser()

    const text = await api('POST', '/api/photos', {
      token: user.token,
      formData: photoForm(new TextEncoder().encode('definitely not an image'), 'notes.txt', 'image/png'),
    })
    expect(text.status).toBe(415)

    const big = new Uint8Array(5 * 1024 * 1024 + 1)
    big.set(PNG_BYTES)
    const oversized = await api('POST', '/api/photos', {
      token: user.token,
      formData: photoForm(big),
    })
    expect(oversized.status).toBe(413)
  })

  it('requires multipart data with a file field', async () => {
    const user = await registerUser()
    const response = await api('POST', '/api/photos', { token: user.token, body: {} })
    expect(response.status).toBe(422)
  })

  it('deletes a photo and detaches it from the birthday', async () => {
    const user = await registerUser()
    const upload = await json<UploadBody>(
      await api('POST', '/api/photos', { token: user.token, formData: photoForm() }),
    )

    const birthday = await createBirthday(user, { name: 'Photo Person' })
    const updated = await api('PUT', `/api/birthdays/${birthday.id}`, {
      token: user.token,
      body: { photoUrl: upload.url },
    })
    expect((await json<{ photoUrl: string }>(updated)).photoUrl).toBe(upload.url)

    expect((await api('DELETE', upload.url, { token: user.token })).status).toBe(200)
    expect(await env.PHOTOS.get(upload.key)).toBeNull()

    const afterDelete = await json<{ photoUrl: string | null }>(
      await api('GET', `/api/birthdays/${birthday.id}`, { token: user.token }),
    )
    expect(afterDelete.photoUrl).toBeNull()
  })

  it('refuses to attach or delete a photo owned by someone else', async () => {
    const owner = await registerUser()
    const stranger = await registerUser()
    const upload = await json<UploadBody>(
      await api('POST', '/api/photos', { token: owner.token, formData: photoForm() }),
    )

    const birthday = await createBirthday(stranger, { name: 'Sneaky' })
    const attach = await api('PUT', `/api/birthdays/${birthday.id}`, {
      token: stranger.token,
      body: { photoUrl: upload.url },
    })
    expect(attach.status).toBe(403)

    expect((await api('DELETE', upload.url, { token: stranger.token })).status).toBe(403)
  })

  it('removes stored photos when the birthday is deleted', async () => {
    const user = await registerUser()
    const upload = await json<UploadBody>(
      await api('POST', '/api/photos', { token: user.token, formData: photoForm() }),
    )
    const birthday = await createBirthday(user, { name: 'Photo Person' })
    await api('PUT', `/api/birthdays/${birthday.id}`, {
      token: user.token,
      body: { photoUrl: upload.url },
    })

    await api('DELETE', `/api/birthdays/${birthday.id}`, { token: user.token })
    expect(await env.PHOTOS.get(upload.key)).toBeNull()
  })
})
