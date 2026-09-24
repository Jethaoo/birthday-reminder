export interface UserRow {
  id: string
  email: string
  password_hash: string
  display_name: string
  timezone: string
  password_changed_at: string
  created_at: string
  updated_at: string
}

export interface BirthdayRow {
  id: string
  user_id: string
  name: string
  normalised_name: string
  birthday_month: number
  birthday_day: number
  birth_year: number | null
  relationship: string | null
  phone: string | null
  email: string | null
  photo_url: string | null
  notes: string | null
  gift_ideas: string
  created_at: string
  updated_at: string
}

export interface ReminderRow {
  id: string
  birthday_id: string
  user_id: string
  days_before: number
  reminder_time: string
  enabled: number
  created_at: string
  updated_at: string
}

export interface DeviceRow {
  id: string
  user_id: string
  fcm_token: string
  platform: string
  device_name: string | null
  active: number
  last_seen_at: string
  created_at: string
  updated_at: string
}

export interface UserSettingsRow {
  user_id: string
  reminders_enabled: number
  today_enabled: number
  tomorrow_enabled: number
  sound_enabled: number
  default_days_before: number
  default_reminder_time: string
  theme_mode: string
  updated_at: string
}

export interface UserDto {
  id: string
  name: string
  email: string
  timezone: string
  createdAt: string
}

export interface ReminderDto {
  id: string
  daysBefore: number
  reminderTime: string
  enabled: boolean
}

export interface BirthdayDto {
  id: string
  name: string
  birthdayMonth: number
  birthdayDay: number
  birthYear: number | null
  relationship: string | null
  phone: string | null
  email: string | null
  photoUrl: string | null
  notes: string | null
  giftIdeas: string[]
  reminders: ReminderDto[]
  /** e.g. `2026-09-30`. */
  nextOccurrence: string
  /** Whole days until the next occurrence, evaluated in the user's timezone. */
  daysUntil: number
  /** Age reached on the next occurrence, or null when the birth year is unknown. */
  turningAge: number | null
  createdAt: string
  updatedAt: string
}

export interface BirthdaySummaryDto {
  id: string
  name: string
  birthdayMonth: number
  birthdayDay: number
  birthYear: number | null
  relationship: string | null
  photoUrl: string | null
  nextOccurrence: string
  daysUntil: number
  turningAge: number | null
}

export interface UserSettingsDto {
  remindersEnabled: boolean
  todayEnabled: boolean
  tomorrowEnabled: boolean
  soundEnabled: boolean
  defaultDaysBefore: number
  defaultReminderTime: string
  themeMode: 'system' | 'light' | 'dark'
}

export interface DeviceDto {
  id: string
  platform: string
  deviceName: string | null
  lastSeenAt: string
}

export interface HomeDto {
  today: BirthdaySummaryDto[]
  upcoming: BirthdaySummaryDto[]
  monthlySummary: {
    month: number
    monthName: string
    year: number
    total: number
    upcoming: number
    today: number
  }
}

export interface CalendarDayDto {
  date: string
  count: number
  birthdays: BirthdaySummaryDto[]
}

export interface CalendarDto {
  month: number
  year: number
  days: CalendarDayDto[]
}

export function toUserDto(row: UserRow): UserDto {
  return {
    id: row.id,
    name: row.display_name,
    email: row.email,
    timezone: row.timezone,
    createdAt: row.created_at,
  }
}

export function toReminderDto(row: ReminderRow): ReminderDto {
  return {
    id: row.id,
    daysBefore: row.days_before,
    reminderTime: row.reminder_time,
    enabled: row.enabled === 1,
  }
}

export function toUserSettingsDto(row: UserSettingsRow): UserSettingsDto {
  return {
    remindersEnabled: row.reminders_enabled === 1,
    todayEnabled: row.today_enabled === 1,
    tomorrowEnabled: row.tomorrow_enabled === 1,
    soundEnabled: row.sound_enabled === 1,
    defaultDaysBefore: row.default_days_before,
    defaultReminderTime: row.default_reminder_time,
    themeMode: (row.theme_mode as UserSettingsDto['themeMode']) ?? 'system',
  }
}

export function toDeviceDto(row: DeviceRow): DeviceDto {
  return {
    id: row.id,
    platform: row.platform,
    deviceName: row.device_name,
    lastSeenAt: row.last_seen_at,
  }
}
