import { describe, expect, it } from 'vitest'
import { api, createBirthday, json, registerUser } from './helpers'

interface ReminderBody {
  id: string
  daysBefore: number
  reminderTime: string
  enabled: boolean
}

describe('reminder management', () => {
  it('creates, lists, updates and deletes reminders', async () => {
    const user = await registerUser()
    const birthday = await createBirthday(user)

    const created = await api('POST', `/api/birthdays/${birthday.id}/reminders`, {
      token: user.token,
      body: { daysBefore: 7, reminderTime: '09:00' },
    })
    expect(created.status).toBe(201)
    const reminder = await json<ReminderBody>(created)
    expect(reminder).toMatchObject({ daysBefore: 7, reminderTime: '09:00', enabled: true })

    const listed = await json<{ items: ReminderBody[] }>(
      await api('GET', `/api/birthdays/${birthday.id}/reminders`, { token: user.token }),
    )
    expect(listed.items).toHaveLength(1)

    const updated = await api('PATCH', `/api/reminders/${reminder.id}`, {
      token: user.token,
      body: { reminderTime: '07:30', enabled: false },
    })
    expect(await json<ReminderBody>(updated)).toMatchObject({
      reminderTime: '07:30',
      enabled: false,
      daysBefore: 7,
    })

    expect((await api('DELETE', `/api/reminders/${reminder.id}`, { token: user.token })).status).toBe(200)
    expect((await api('DELETE', `/api/reminders/${reminder.id}`, { token: user.token })).status).toBe(404)
  })

  it('supports several reminders on one birthday', async () => {
    const user = await registerUser()
    const birthday = await createBirthday(user, {
      reminders: [
        { daysBefore: 7, reminderTime: '09:00' },
        { daysBefore: 1, reminderTime: '09:00' },
        { daysBefore: 0, reminderTime: '09:00' },
      ],
    })

    const reminders = birthday.reminders as ReminderBody[]
    expect(reminders).toHaveLength(3)
    expect(reminders.map((item) => item.daysBefore).sort((a, b) => a - b)).toEqual([0, 1, 7])
  })

  it('rejects duplicate day and time combinations', async () => {
    const user = await registerUser()
    const birthday = await createBirthday(user)

    await api('POST', `/api/birthdays/${birthday.id}/reminders`, {
      token: user.token,
      body: { daysBefore: 7, reminderTime: '09:00' },
    })
    const duplicate = await api('POST', `/api/birthdays/${birthday.id}/reminders`, {
      token: user.token,
      body: { daysBefore: 7, reminderTime: '09:00' },
    })
    expect(duplicate.status).toBe(409)
  })

  it('rejects unsupported periods, bad times and duplicate entries in one payload', async () => {
    const user = await registerUser()
    const birthday = await createBirthday(user)

    expect(
      (
        await api('POST', `/api/birthdays/${birthday.id}/reminders`, {
          token: user.token,
          body: { daysBefore: 2, reminderTime: '09:00' },
        })
      ).status,
    ).toBe(422)

    expect(
      (
        await api('POST', `/api/birthdays/${birthday.id}/reminders`, {
          token: user.token,
          body: { daysBefore: 7, reminderTime: '9am' },
        })
      ).status,
    ).toBe(422)

    expect(
      (
        await api('PUT', `/api/birthdays/${birthday.id}`, {
          token: user.token,
          body: {
            reminders: [
              { daysBefore: 7, reminderTime: '09:00' },
              { daysBefore: 7, reminderTime: '09:00' },
            ],
          },
        })
      ).status,
    ).toBe(422)
  })

  it('keeps reminders scoped to their owner', async () => {
    const owner = await registerUser()
    const stranger = await registerUser()
    const birthday = await createBirthday(owner)

    const created = await json<ReminderBody>(
      await api('POST', `/api/birthdays/${birthday.id}/reminders`, {
        token: owner.token,
        body: { daysBefore: 7, reminderTime: '09:00' },
      }),
    )

    expect((await api('GET', `/api/birthdays/${birthday.id}/reminders`, { token: stranger.token })).status).toBe(
      404,
    )
    expect(
      (
        await api('PATCH', `/api/reminders/${created.id}`, {
          token: stranger.token,
          body: { reminderTime: '10:00' },
        })
      ).status,
    ).toBe(404)
    expect((await api('DELETE', `/api/reminders/${created.id}`, { token: stranger.token })).status).toBe(404)
  })
})

describe('notification settings', () => {
  it('updates preferences and the default reminder', async () => {
    const user = await registerUser()

    const response = await api('PATCH', '/api/settings', {
      token: user.token,
      body: {
        tomorrowEnabled: false,
        soundEnabled: false,
        defaultDaysBefore: 1,
        defaultReminderTime: '08:00',
        themeMode: 'dark',
      },
    })

    expect(response.status).toBe(200)
    expect(await json(response)).toMatchObject({
      tomorrowEnabled: false,
      soundEnabled: false,
      remindersEnabled: true,
      defaultDaysBefore: 1,
      defaultReminderTime: '08:00',
      themeMode: 'dark',
    })
  })

  it('rejects invalid settings values', async () => {
    const user = await registerUser()
    expect(
      (
        await api('PATCH', '/api/settings', {
          token: user.token,
          body: { defaultDaysBefore: 5 },
        })
      ).status,
    ).toBe(422)
    expect(
      (
        await api('PATCH', '/api/settings', {
          token: user.token,
          body: { themeMode: 'sepia' },
        })
      ).status,
    ).toBe(422)
  })
})
