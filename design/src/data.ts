export type Person = {
  id: string
  name: string
  initials: string
  tint: number
  day: number
  month: number
  monthName: string
  relationship: string
  days: number
  birthYear?: number
  phone?: string
  email?: string
  notes?: string
  giftIdeas: string[]
  reminders: { id: string; daysBefore: number; time: string; enabled: boolean }[]
}

export const people: Person[] = [
  {
    id: 'sarah-tan',
    name: 'Sarah Tan',
    initials: 'ST',
    tint: 0,
    day: 23,
    month: 9,
    monthName: 'September',
    relationship: 'Friend',
    days: 0,
    birthYear: 2000,
    phone: '+60 12-345 6789',
    email: 'sarah@example.com',
    notes: 'Likes travelling and lavender scents.',
    giftIdeas: ['Perfume', 'Chocolate', 'Travel journal'],
    reminders: [
      { id: 'r1', daysBefore: 7, time: '09:00', enabled: true },
      { id: 'r2', daysBefore: 1, time: '09:00', enabled: true },
      { id: 'r3', daysBefore: 0, time: '09:00', enabled: true },
    ],
  },
  {
    id: 'alex-lim',
    name: 'Alex Lim',
    initials: 'AL',
    tint: 1,
    day: 5,
    month: 10,
    monthName: 'October',
    relationship: 'Family',
    days: 12,
    birthYear: 1995,
    giftIdeas: ['Coffee beans'],
    reminders: [{ id: 'r4', daysBefore: 7, time: '08:30', enabled: true }],
  },
  {
    id: 'jason-lee',
    name: 'Jason Lee',
    initials: 'JL',
    tint: 2,
    day: 12,
    month: 10,
    monthName: 'October',
    relationship: 'Colleague',
    days: 19,
    giftIdeas: [],
    reminders: [],
  },
  {
    id: 'maya-patel',
    name: 'Maya Patel',
    initials: 'MP',
    tint: 3,
    day: 18,
    month: 10,
    monthName: 'October',
    relationship: 'Friend',
    days: 25,
    notes: 'Allergic to nuts.',
    giftIdeas: ['Book'],
    reminders: [{ id: 'r5', daysBefore: 3, time: '09:00', enabled: false }],
  },
  {
    id: 'leap-baby',
    name: 'Nur Iman',
    initials: 'NI',
    tint: 0,
    day: 29,
    month: 2,
    monthName: 'February',
    relationship: 'Family',
    days: 158,
    birthYear: 2004,
    giftIdeas: [],
    reminders: [{ id: 'r6', daysBefore: 14, time: '09:00', enabled: true }],
  },
]

export const todayPeople = people.filter((person) => person.days === 0)
export const upcomingPeople = people.filter((person) => person.days > 0)

export const monthlySummary = { monthName: 'September', total: 5, upcoming: 2, today: 1 }

export const selectedDayBirthdays = [people[0]]

export const contacts = [
  { id: 'c1', name: 'Sarah Tan', day: 23, month: 9, selected: true },
  { id: 'c2', name: 'Alex Lim', day: 5, month: 10, selected: false },
  { id: 'c3', name: 'Michael Lee', day: 30, month: 9, selected: true },
  { id: 'c4', name: 'Jason Wong', day: 2, month: 11, selected: false },
]
