import { describe, expect, it } from 'vitest'
import {
  addDaysIso,
  api,
  createBirthday,
  json,
  localToday,
  monthDayOf,
  registerUser,
} from './helpers'

interface BirthdayBody {
  id: string
  name: string
  birthdayMonth: number
  birthdayDay: number
  birthYear: number | null
  relationship: string | null
  giftIdeas: string[]
  reminders: Array<{ id: string; daysBefore: number; reminderTime: string; enabled: boolean }>
  nextOccurrence: string
  daysUntil: number
  turningAge: number | null
}

describe('creating birthdays', () => {
  it('saves a birthday with only a name and date', async () => {
    const user = await registerUser()
    const response = await api('POST', '/api/birthdays', {
      token: user.token,
      body: { name: 'Sarah Tan', birthdayMonth: 9, birthdayDay: 30 },
    })

    expect(response.status).toBe(201)
    const body = await json<BirthdayBody>(response)
    expect(body).toMatchObject({
      name: 'Sarah Tan',
      birthdayMonth: 9,
      birthdayDay: 30,
      birthYear: null,
      relationship: null,
      giftIdeas: [],
      reminders: [],
      turningAge: null,
    })
  })

  it('computes the next occurrence, countdown and age', async () => {
    const user = await registerUser()
    const today = localToday()
    const target = addDaysIso(today.iso, 7)
    const { month, day } = monthDayOf(target)
    const occurrenceYear = Number(target.slice(0, 4))

    const body = await createBirthday(user, {
      name: 'Alex Lim',
      birthdayMonth: month,
      birthdayDay: day,
      birthYear: occurrenceYear - 26,
    })

    expect(body.nextOccurrence).toBe(target)
    expect(body.daysUntil).toBe(7)
    expect(body.turningAge).toBe(26)
  })

  it('stores gift ideas and relationship', async () => {
    const user = await registerUser()
    const body = await createBirthday(user, {
      relationship: 'Friend',
      giftIdeas: ['Perfume', 'Chocolate'],
    })
    expect(body.giftIdeas).toEqual(['Perfume', 'Chocolate'])
    expect(body.relationship).toBe('Friend')
  })

  it('supports 29 February birthdays', async () => {
    const user = await registerUser()
    const body = await createBirthday(user, { name: 'Leap Baby', birthdayMonth: 2, birthdayDay: 29 })
    expect(body.birthdayMonth).toBe(2)
    expect(body.birthdayDay).toBe(29)
    expect(body.daysUntil).toBeGreaterThanOrEqual(0)
    expect(body.daysUntil).toBeLessThanOrEqual(366)
  })

  it('rejects an empty name and impossible dates', async () => {
    const user = await registerUser()

    expect(
      (
        await api('POST', '/api/birthdays', {
          token: user.token,
          body: { name: '   ', birthdayMonth: 9, birthdayDay: 30 },
        })
      ).status,
    ).toBe(422)

    expect(
      (
        await api('POST', '/api/birthdays', {
          token: user.token,
          body: { name: 'Bad Date', birthdayMonth: 13, birthdayDay: 4 },
        })
      ).status,
    ).toBe(422)

    expect(
      (
        await api('POST', '/api/birthdays', {
          token: user.token,
          body: { name: 'Bad Date', birthdayMonth: 4, birthdayDay: 31 },
        })
      ).status,
    ).toBe(422)
  })

  it('reports a duplicate with the existing birthday id', async () => {
    const user = await registerUser()
    const first = await createBirthday(user, { name: 'Sarah Tan' })

    const duplicate = await api('POST', '/api/birthdays', {
      token: user.token,
      body: { name: '  sarah   tan ', birthdayMonth: 9, birthdayDay: 30 },
    })

    expect(duplicate.status).toBe(409)
    expect(await json<{ error: { code: string; details: { existingBirthdayId: string } } }>(duplicate)).toMatchObject({
      error: { code: 'CONFLICT', details: { existingBirthdayId: first.id } },
    })
  })
})

describe('owning birthdays', () => {
  it('never exposes one user´s birthday to another', async () => {
    const owner = await registerUser()
    const stranger = await registerUser()
    const birthday = await createBirthday(owner, { name: 'Private Person' })

    expect((await api('GET', `/api/birthdays/${birthday.id}`, { token: stranger.token })).status).toBe(404)
    expect(
      (
        await api('PUT', `/api/birthdays/${birthday.id}`, {
          token: stranger.token,
          body: { name: 'Hacked' },
        })
      ).status,
    ).toBe(404)
    expect((await api('DELETE', `/api/birthdays/${birthday.id}`, { token: stranger.token })).status).toBe(404)

    const listing = await api('GET', '/api/birthdays', { token: stranger.token })
    expect((await json<{ items: unknown[] }>(listing)).items).toHaveLength(0)

    // The owner still sees the untouched record.
    const owned = await api('GET', `/api/birthdays/${birthday.id}`, { token: owner.token })
    expect((await json<BirthdayBody>(owned)).name).toBe('Private Person')
  })
})

describe('listing birthdays', () => {
  async function seed() {
    const user = await registerUser()
    const today = localToday()

    const todayDate = monthDayOf(today.iso)
    const soonDate = monthDayOf(addDaysIso(today.iso, 3))
    const farDate = monthDayOf(addDaysIso(today.iso, 200))

    await createBirthday(user, {
      name: 'Today Person',
      birthdayMonth: todayDate.month,
      birthdayDay: todayDate.day,
      relationship: 'Family',
    })
    await createBirthday(user, {
      name: 'Soon Person',
      birthdayMonth: soonDate.month,
      birthdayDay: soonDate.day,
      relationship: 'Colleague',
      notes: 'Likes travelling',
    })
    await createBirthday(user, {
      name: 'Far Person',
      birthdayMonth: farDate.month,
      birthdayDay: farDate.day,
      relationship: 'Friend',
    })

    return user
  }

  it('sorts by upcoming date by default', async () => {
    const user = await seed()
    const response = await api('GET', '/api/birthdays', { token: user.token })
    const body = await json<{ items: BirthdayBody[]; total: number }>(response)

    expect(body.total).toBe(3)
    const days = body.items.map((item) => item.daysUntil)
    expect([...days].sort((a, b) => a - b)).toEqual(days)
  })

  it('searches name, relationship and notes', async () => {
    const user = await seed()

    const byName = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?search=soon', { token: user.token }),
    )
    expect(byName.items.map((item) => item.name)).toEqual(['Soon Person'])

    const byRelationship = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?search=family', { token: user.token }),
    )
    expect(byRelationship.items.map((item) => item.name)).toEqual(['Today Person'])

    const byNotes = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?search=travelling', { token: user.token }),
    )
    expect(byNotes.items.map((item) => item.name)).toEqual(['Soon Person'])

    const empty = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?search=nobodyhere', { token: user.token }),
    )
    expect(empty.items).toHaveLength(0)
  })

  it('filters by period and relationship', async () => {
    const user = await seed()

    const today = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?filter=today', { token: user.token }),
    )
    expect(today.items.map((item) => item.name)).toEqual(['Today Person'])

    const week = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?filter=this_week', { token: user.token }),
    )
    expect(week.items.map((item) => item.name)).toContain('Soon Person')

    const colleagues = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?filter=colleague', { token: user.token }),
    )
    expect(colleagues.items.map((item) => item.name)).toEqual(['Soon Person'])

    const other = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?filter=other', { token: user.token }),
    )
    expect(other.items).toHaveLength(0)
  })

  it('sorts by name and reports totals', async () => {
    const user = await seed()
    const body = await json<{ items: BirthdayBody[] }>(
      await api('GET', '/api/birthdays?sort=name', { token: user.token }),
    )
    expect(body.items.map((item) => item.name)).toEqual(['Far Person', 'Soon Person', 'Today Person'])
  })

  it('paginates with limit and offset', async () => {
    const user = await seed()
    const firstPage = await json<{ items: BirthdayBody[]; total: number; limit: number; offset: number }>(
      await api('GET', '/api/birthdays?limit=2&offset=0', { token: user.token }),
    )
    const secondPage = await json<{ items: BirthdayBody[]; total: number }>(
      await api('GET', '/api/birthdays?limit=2&offset=2', { token: user.token }),
    )

    expect(firstPage.items).toHaveLength(2)
    expect(firstPage.total).toBe(3)
    expect(secondPage.items).toHaveLength(1)
  })

  it('rejects unknown filter, sort and pagination values', async () => {
    const user = await seed()
    expect((await api('GET', '/api/birthdays?filter=whenever', { token: user.token })).status).toBe(422)
    expect((await api('GET', '/api/birthdays?sort=magic', { token: user.token })).status).toBe(422)
    expect((await api('GET', '/api/birthdays?limit=999', { token: user.token })).status).toBe(422)
  })
})

describe('updating and deleting', () => {
  it('updates every editable field', async () => {
    const user = await registerUser()
    const created = await createBirthday(user, { name: 'Sarah Tan', birthYear: 2000 })

    const response = await api('PUT', `/api/birthdays/${created.id}`, {
      token: user.token,
      body: {
        name: 'Sarah Tan-Lim',
        birthdayMonth: 10,
        birthdayDay: 2,
        birthYear: 1999,
        relationship: 'Family',
        phone: '+60123456789',
        email: 'sarah@example.com',
        notes: 'Likes travelling',
        giftIdeas: ['Book'],
      },
    })

    expect(response.status).toBe(200)
    const body = await json<BirthdayBody & { phone: string; notes: string }>(response)
    expect(body).toMatchObject({
      name: 'Sarah Tan-Lim',
      birthdayMonth: 10,
      birthdayDay: 2,
      birthYear: 1999,
      relationship: 'Family',
      phone: '+60123456789',
      notes: 'Likes travelling',
      giftIdeas: ['Book'],
    })
  })

  it('replaces the reminder set when reminders are sent with an update', async () => {
    const user = await registerUser()
    const created = await createBirthday(user, {
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })
    expect(created.reminders).toHaveLength(1)

    const updated = await json<BirthdayBody>(
      await api('PUT', `/api/birthdays/${created.id}`, {
        token: user.token,
        body: { reminders: [{ daysBefore: 1, reminderTime: '08:30' }, { daysBefore: 0, reminderTime: '09:00' }] },
      }),
    )

    expect(updated.reminders.map((reminder) => reminder.daysBefore).sort()).toEqual([0, 1])
  })

  it('deletes the birthday and its reminders', async () => {
    const user = await registerUser()
    const created = await createBirthday(user, {
      reminders: [{ daysBefore: 7, reminderTime: '09:00' }],
    })

    expect((await api('DELETE', `/api/birthdays/${created.id}`, { token: user.token })).status).toBe(200)
    expect((await api('GET', `/api/birthdays/${created.id}`, { token: user.token })).status).toBe(404)

    const reminders = await api('GET', `/api/birthdays/${created.id}/reminders`, { token: user.token })
    expect(reminders.status).toBe(404)
  })
})

describe('home and calendar', () => {
  it('returns today, upcoming and a monthly summary without the whole list', async () => {
    const user = await registerUser()
    const today = localToday()
    const todayDate = monthDayOf(today.iso)
    const soon = monthDayOf(addDaysIso(today.iso, 2))

    await createBirthday(user, {
      name: 'Today Person',
      birthdayMonth: todayDate.month,
      birthdayDay: todayDate.day,
    })
    await createBirthday(user, {
      name: 'Soon Person',
      birthdayMonth: soon.month,
      birthdayDay: soon.day,
    })

    const response = await api('GET', '/api/home', { token: user.token })
    expect(response.status).toBe(200)

    const body = await json<{
      today: BirthdayBody[]
      upcoming: BirthdayBody[]
      monthlySummary: { month: number; total: number; upcoming: number; today: number }
    }>(response)

    expect(body.today.map((item) => item.name)).toEqual(['Today Person'])
    expect(body.upcoming.map((item) => item.name)).toContain('Soon Person')
    expect(body.monthlySummary.today).toBe(1)
    expect(body.monthlySummary.total).toBeGreaterThanOrEqual(1)
  })

  it('marks calendar days that contain birthdays', async () => {
    const user = await registerUser()
    const target = addDaysIso(localToday().iso, 10)
    const { month, day } = monthDayOf(target)

    await createBirthday(user, { name: 'Calendar Person', birthdayMonth: month, birthdayDay: day })

    const response = await api(
      'GET',
      `/api/calendar?month=${month}&year=${target.slice(0, 4)}`,
      { token: user.token },
    )
    expect(response.status).toBe(200)

    const body = await json<{ days: Array<{ date: string; count: number; birthdays: BirthdayBody[] }> }>(
      response,
    )
    const entry = body.days.find((item) => item.date === target)
    expect(entry?.count).toBe(1)
    expect(entry?.birthdays[0]?.name).toBe('Calendar Person')
  })

  it('observes 29 February birthdays on 28 February in non-leap years', async () => {
    const user = await registerUser()
    await createBirthday(user, { name: 'Leap Baby', birthdayMonth: 2, birthdayDay: 29 })

    const body = await json<{ days: Array<{ date: string }> }>(
      await api('GET', '/api/calendar?month=2&year=2026', { token: user.token }),
    )
    expect(body.days.map((item) => item.date)).toContain('2026-02-28')

    const leap = await json<{ days: Array<{ date: string }> }>(
      await api('GET', '/api/calendar?month=2&year=2024', { token: user.token }),
    )
    expect(leap.days.map((item) => item.date)).toContain('2024-02-29')
  })
})
