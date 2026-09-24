import { SELF } from 'cloudflare:test'

let counter = 0

export interface TestUser {
  id: string
  token: string
  email: string
  password: string
}

/** Rate limiting is keyed per IP, so each helper call uses a fresh address. */
export function uniqueIp(): string {
  counter += 1
  return `10.${(counter >> 16) & 255}.${(counter >> 8) & 255}.${(counter % 255) + 1}`
}

export function uniqueEmail(prefix = 'user'): string {
  counter += 1
  return `${prefix}${counter}.${Date.now()}@example.com`
}

interface RequestOptions {
  token?: string
  body?: unknown
  formData?: FormData
  ip?: string
  headers?: Record<string, string>
}

export async function api(
  method: string,
  path: string,
  options: RequestOptions = {},
): Promise<Response> {
  const headers: Record<string, string> = {
    'CF-Connecting-IP': options.ip ?? uniqueIp(),
    ...options.headers,
  }

  if (options.token) headers.Authorization = `Bearer ${options.token}`

  let body: BodyInit | undefined
  if (options.formData) {
    body = options.formData
  } else if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(options.body)
  }

  return SELF.fetch(`https://example.com${path}`, { method, headers, body })
}

export async function json<T = unknown>(response: Response): Promise<T> {
  return (await response.json()) as T
}

/** Today's calendar date in a timezone, computed independently of the Worker. */
export function localToday(timeZone = 'Asia/Kuala_Lumpur', instant = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(instant)
  const lookup = new Map(parts.map((part) => [part.type, part.value]))
  const year = Number(lookup.get('year'))
  const month = Number(lookup.get('month'))
  const day = Number(lookup.get('day'))
  return { year, month, day, iso: toIso({ year, month, day }) }
}

export function toIso(date: { year: number; month: number; day: number }): string {
  return `${date.year}-${String(date.month).padStart(2, '0')}-${String(date.day).padStart(2, '0')}`
}

export function addDaysIso(iso: string, delta: number): string {
  const [year, month, day] = iso.split('-').map(Number) as [number, number, number]
  const shifted = new Date(Date.UTC(year, month - 1, day) + delta * 86_400_000)
  return toIso({
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  })
}

export function monthDayOf(iso: string): { month: number; day: number } {
  const [, month, day] = iso.split('-').map(Number) as [number, number, number]
  return { month, day }
}

export async function registerUser(
  overrides: Partial<{ name: string; email: string; password: string; timezone: string }> = {},
): Promise<TestUser> {
  const email = overrides.email ?? uniqueEmail()
  const password = overrides.password ?? 'Password123'

  const response = await api('POST', '/api/auth/register', {
    body: {
      name: overrides.name ?? 'Test User',
      email,
      password,
      confirmPassword: password,
      timezone: overrides.timezone ?? 'Asia/Kuala_Lumpur',
    },
  })

  if (response.status !== 201) {
    throw new Error(`register failed: ${response.status} ${await response.text()}`)
  }

  const payload = await json<{ user: { id: string }; accessToken: string }>(response)
  return { id: payload.user.id, token: payload.accessToken, email, password }
}

export interface BirthdayInput {
  name?: string
  birthdayMonth?: number
  birthdayDay?: number
  birthYear?: number | null
  relationship?: string | null
  notes?: string | null
  giftIdeas?: string[]
  reminders?: Array<{ daysBefore: number; reminderTime: string; enabled?: boolean }>
}

export async function createBirthday(
  user: TestUser,
  overrides: BirthdayInput = {},
): Promise<Record<string, unknown> & { id: string }> {
  const response = await api('POST', '/api/birthdays', {
    token: user.token,
    body: {
      name: overrides.name ?? 'Sarah Tan',
      birthdayMonth: overrides.birthdayMonth ?? 9,
      birthdayDay: overrides.birthdayDay ?? 30,
      birthYear: overrides.birthYear ?? 2000,
      relationship: overrides.relationship ?? 'Friend',
      notes: overrides.notes ?? null,
      giftIdeas: overrides.giftIdeas ?? [],
      ...(overrides.reminders ? { reminders: overrides.reminders } : {}),
    },
  })

  if (response.status !== 201) {
    throw new Error(`create birthday failed: ${response.status} ${await response.text()}`)
  }

  return json(response)
}
