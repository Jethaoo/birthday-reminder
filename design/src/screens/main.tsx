import {
  Avatar,
  BirthdayRow,
  BottomNav,
  Card,
  Chip,
  Label,
  MonthlySummaryCard,
  Pill,
  PrimaryButton,
  ReminderRow,
  ScreenFrame,
  SectionHeader,
  TextButton,
  TodayCard,
  Toggle,
} from '../components'
import { contacts, people, todayPeople, upcomingPeople } from '../data'
import { countdownLabel, light, relationshipFilters, reminderLabel, typography } from '../theme'

const p = light
const currentYear = new Date().getFullYear()

export function HomeScreen() {
  const today = todayPeople[0] ?? people[0]
  return (
    <ScreenFrame title="Home" sub="Today, coming up, monthly summary">
      <header className="flex items-start justify-between">
        <div>
          <p className="text-[13px] font-semibold" style={{ color: p.textSecondary }}>
            Tuesday, 23 September
          </p>
          <h1 className={`mt-1 ${typography.display}`}>Good morning 👋</h1>
        </div>
        <span
          className="grid h-11 w-11 place-items-center rounded-full text-[13px] font-bold"
          style={{ background: p.primary, color: p.onPrimary }}
        >
          JD
        </span>
      </header>

      <section className="mt-8">
        <SectionHeader title="Today's birthdays" trailing={<Pill>1 today</Pill>} />
        <TodayCard person={today} />
      </section>

      <section className="mt-8">
        <SectionHeader title="Coming up" trailing={<TextButton>View all</TextButton>} />
        <div className="space-y-2">
          {upcomingPeople.slice(0, 3).map((person) => (
            <BirthdayRow key={person.id} person={person} />
          ))}
        </div>
      </section>

      <section className="mt-6">
        <MonthlySummaryCard />
      </section>
      <BottomNav active="Home" />
    </ScreenFrame>
  )
}

export function HomeEmptyScreen() {
  return (
    <ScreenFrame title="Home — empty" sub="No birthdays yet">
      <h1 className={typography.display}>Good morning 👋</h1>
      <div className="mt-6">
        <SectionHeader title="Today's birthdays" />
        <Card>
          <b className="block text-[15px]">No birthdays today</b>
          <span className="text-[12px]" style={{ color: p.textSecondary }}>
            Enjoy the day! 🎉
          </span>
        </Card>
      </div>
      <div className="mt-6 flex flex-col items-center px-2 py-8 text-center">
        <span className="text-[40px]">🎂</span>
        <p className="mt-4 text-[16px] font-bold">No birthdays yet</p>
        <p className="mt-2 text-[13px]" style={{ color: p.textSecondary }}>
          Add your first birthday and never forget an important date.
        </p>
        <div className="mt-5 w-full">
          <PrimaryButton>Add birthday</PrimaryButton>
        </div>
      </div>
      <BottomNav active="Home" />
    </ScreenFrame>
  )
}

export function BirthdaysScreen() {
  return (
    <ScreenFrame title="Birthdays" sub="Search, filters, sort, list">
      <div className="flex items-center justify-between">
        <h1 className={typography.display}>Birthdays</h1>
        <span
          className="flex items-center gap-1.5 rounded-full px-3.5 py-2 text-[12px] font-bold"
          style={{ background: p.surface, border: `1px solid ${p.border}` }}
        >
          ⇅ Upcoming
        </span>
      </div>
      <label
        className="mt-4 flex items-center gap-2 rounded-[16px] px-4 py-3 text-[14px]"
        style={{ background: p.surfaceVariant, color: p.textSecondary }}
      >
        <span>⌕</span>
        <input
          className="w-full bg-transparent outline-none"
          placeholder="Search birthdays..."
          style={{ color: p.textPrimary }}
        />
      </label>
      <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
        {relationshipFilters.map((filter, index) => (
          <Chip key={filter} active={index === 0}>
            {filter}
          </Chip>
        ))}
      </div>
      <div className="mt-6 space-y-2">
        {people.slice(0, 4).map((person) => (
          <BirthdayRow key={person.id} person={person} />
        ))}
        <p className="pt-3 text-center text-[12px]" style={{ color: p.textSecondary }}>
          5 birthdays
        </p>
      </div>
      <BottomNav active="Birthdays" />
    </ScreenFrame>
  )
}

export function BirthdaysNoResultsScreen() {
  return (
    <ScreenFrame title="Birthdays — no results" sub="Search and filter empty state">
      <h1 className={typography.display}>Birthdays</h1>
      <label
        className="mt-4 flex items-center gap-2 rounded-[16px] px-4 py-3 text-[14px]"
        style={{ background: p.surfaceVariant, color: p.textSecondary }}
      >
        <span>⌕</span>
        <input className="w-full bg-transparent outline-none" value="zzz" readOnly style={{ color: p.textPrimary }} />
      </label>
      <div className="flex flex-col items-center px-6 py-16 text-center">
        <span className="text-[40px]">🎂</span>
        <p className="mt-4 text-[16px] font-bold">No birthdays found</p>
        <p className="mt-2 text-[13px]" style={{ color: p.textSecondary }}>
          Try another search or filter.
        </p>
      </div>
      <BottomNav active="Birthdays" />
    </ScreenFrame>
  )
}

export function BirthdayDetailsScreen() {
  const person = people[0]
  return (
    <ScreenFrame title="Birthday details" sub="Photo, countdown, gifts, notes, reminders">
      <div className="text-center">
        <div className="flex justify-center">
          <Avatar person={person} size={88} />
        </div>
        <h1 className={`mt-4 ${typography.display}`}>{person.name}</h1>
        <p className="mt-1 text-[14px]" style={{ color: p.textSecondary }}>
          {person.day} {person.monthName} · {person.relationship}
        </p>
        <div className="mt-3 flex justify-center">
          <Pill>🎂 Today</Pill>
        </div>
      </div>

      <div className="mt-6 space-y-3">
        <Card>
          <Label>Birthday</Label>
          <b className="mt-2 block text-[15px]">
            {person.day} {person.monthName}
          </b>
          {person.birthYear ? (
            <span className="text-[12px]" style={{ color: p.textSecondary }}>
              Turning {currentYear - person.birthYear}
            </span>
          ) : null}
        </Card>

        <Card>
          <div className="flex items-center justify-between">
            <Label>Reminders</Label>
            <TextButton>Add</TextButton>
          </div>
          <div className="mt-2 divide-y" style={{ borderColor: p.border }}>
            {person.reminders.map((reminder) => (
              <ReminderRow key={reminder.id} reminder={reminder} />
            ))}
          </div>
        </Card>

        <Card>
          <Label>Gift ideas</Label>
          <div className="mt-3 flex flex-wrap gap-2">
            {person.giftIdeas.map((idea) => (
              <span
                key={idea}
                className="rounded-full px-3 py-1.5 text-[12px] font-semibold"
                style={{ background: p.surfaceVariant }}
              >
                {idea}
              </span>
            ))}
          </div>
        </Card>

        <Card>
          <Label>Notes</Label>
          <p className="mt-2 text-[14px]">{person.notes}</p>
        </Card>

        <Card>
          <Label>Contact</Label>
          <div className="mt-2 space-y-2 text-[14px]">
            <p className="flex justify-between">
              {person.phone} <span style={{ color: p.textSecondary }}>copy</span>
            </p>
            <p className="flex justify-between">
              {person.email} <span style={{ color: p.textSecondary }}>copy</span>
            </p>
          </div>
        </Card>
      </div>

      <div className="mt-5 space-y-2">
        <PrimaryButton>Edit birthday</PrimaryButton>
        <p className="text-center text-[13px] font-bold" style={{ color: p.error }}>
          Delete birthday
        </p>
      </div>
    </ScreenFrame>
  )
}

export function AddBirthdayScreen() {
  return (
    <ScreenFrame title="Add birthday" sub="Only name + birthday are required">
      <h1 className={typography.display}>Add birthday</h1>
      <div className="mt-5 space-y-4">
        <div className="flex flex-col items-center">
          <Avatar person={{ initials: 'ST', tint: 0 }} size={84} />
          <TextButton>Add photo</TextButton>
        </div>
        <div>
          <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
            Name *
          </span>
          <input
            className="mt-2 w-full rounded-[14px] px-4 py-3 text-[14px] outline-none"
            style={{ background: p.surface, border: `1px solid ${p.border}`, color: p.textPrimary }}
            defaultValue="Sarah Tan"
          />
        </div>
        <div>
          <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
            Birthday *
          </span>
          <div
            className="mt-2 rounded-[14px] px-4 py-3 text-[14px]"
            style={{ background: p.surface, border: `1px solid ${p.border}` }}
          >
            30 September
          </div>
          <p className="mt-1.5 text-[11px]" style={{ color: p.textSecondary }}>
            29 February birthdays are celebrated on 28 February in non-leap years.
          </p>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
              Birth year
            </span>
            <div
              className="mt-2 rounded-[14px] px-4 py-3 text-[14px]"
              style={{ background: p.surface, border: `1px solid ${p.border}` }}
            >
              2000
            </div>
          </div>
          <div>
            <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
              Relationship
            </span>
            <div
              className="mt-2 rounded-[14px] px-4 py-3 text-[14px]"
              style={{ background: p.surface, border: `1px solid ${p.border}` }}
            >
              Friend ▾
            </div>
          </div>
        </div>
        <div className="rounded-[18px] p-4" style={{ background: p.surface, border: `1px solid ${p.border}` }}>
          <div className="flex items-center justify-between">
            <span className="text-[14px] font-bold">Enable reminders</span>
            <Toggle on />
          </div>
          <div className="mt-3 space-y-1 text-[13px]">
            <p className="flex justify-between">
              {reminderLabel(7)} <span style={{ color: p.textSecondary }}>09:00</span>
            </p>
            <p className="flex justify-between">
              {reminderLabel(0)} <span style={{ color: p.textSecondary }}>09:00</span>
            </p>
          </div>
        </div>
        <PrimaryButton>Save birthday</PrimaryButton>
        <p className="text-center text-[13px] font-bold" style={{ color: p.textSecondary }}>
          Import from contacts
        </p>
      </div>
    </ScreenFrame>
  )
}

export function EditBirthdayScreen() {
  return (
    <ScreenFrame title="Edit birthday" sub="Same form, prefilled, delete available">
      <h1 className={typography.display}>Edit birthday</h1>
      <div className="mt-5 space-y-4">
        <div className="flex flex-col items-center">
          <Avatar person={{ initials: 'ST', tint: 0 }} size={84} />
          <div className="flex gap-4">
            <TextButton>Change photo</TextButton>
            <span className="text-[13px] font-bold" style={{ color: p.error }}>
              Remove
            </span>
          </div>
        </div>
        <div className="space-y-3 text-[14px]">
          {[
            ['Name', 'Sarah Tan'],
            ['Birthday', '30 September'],
            ['Birth year', '2000'],
            ['Phone', '+60 12-345 6789'],
            ['Email', 'sarah@example.com'],
          ].map(([label, value]) => (
            <div key={label}>
              <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
                {label}
              </span>
              <div
                className="mt-2 rounded-[14px] px-4 py-3"
                style={{ background: p.surface, border: `1px solid ${p.border}` }}
              >
                {value}
              </div>
            </div>
          ))}
        </div>
        <PrimaryButton>Save changes</PrimaryButton>
      </div>
    </ScreenFrame>
  )
}

export function ReminderEditorScreen() {
  return (
    <ScreenFrame title="Reminder editor" sub="Add, retime, disable or remove">
      <div className="mx-auto h-1.5 w-10 rounded-full" style={{ background: p.border }} />
      <h2 className="mt-5 text-[22px] font-bold">Reminders</h2>
      <p className="mt-1 text-[13px]" style={{ color: p.textSecondary }}>
        Sarah Tan · 30 September
      </p>
      <div className="mt-5 space-y-3">
        {people[0].reminders.map((reminder) => (
          <Card key={reminder.id}>
            <div className="flex items-center justify-between">
              <span>
                <b className="block text-[15px]">{reminderLabel(reminder.daysBefore)}</b>
                <span className="text-[12px]" style={{ color: p.textSecondary }}>
                  09:00 AM
                </span>
              </span>
              <Toggle on={reminder.enabled} />
            </div>
          </Card>
        ))}
      </div>
      <div className="mt-5">
        <PrimaryButton>Add another reminder</PrimaryButton>
      </div>
      <div className="mt-6">
        <Label>Available periods</Label>
        <div className="mt-2 flex flex-wrap gap-2">
          {[0, 1, 3, 7, 14, 30].map((days) => (
            <Chip key={days}>{reminderLabel(days)}</Chip>
          ))}
        </div>
      </div>
    </ScreenFrame>
  )
}

export function CalendarScreen() {
  const firstDay = new Date(2026, 8, 1)
  const leading = (firstDay.getDay() + 6) % 7
  const grid = Array.from({ length: 42 }, (_, index) => new Date(2026, 8, 1 - leading + index))
  const birthdayDays = new Set([23, 30])

  return (
    <ScreenFrame title="Calendar" sub="Month navigation, indicators, day list">
      <div className="flex items-center justify-between">
        <h1 className={typography.display}>Calendar</h1>
        <span className="rounded-full px-3 py-2 text-[14px]" style={{ background: p.surface }}>
          ⋯
        </span>
      </div>
      <div className="mt-6 rounded-[22px] p-4" style={{ background: p.surface, border: `1px solid ${p.border}` }}>
        <div className="flex items-center justify-between">
          <button className="text-[18px]">‹</button>
          <b>September 2026</b>
          <button className="text-[18px]">›</button>
        </div>
        <div className="mt-4 grid grid-cols-7 gap-y-2 text-center text-[11px] font-bold" style={{ color: p.textSecondary }}>
          {['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((day) => (
            <span key={day}>{day}</span>
          ))}
        </div>
        <div className="mt-3 grid grid-cols-7 gap-y-2 text-center text-[13px]">
          {grid.map((date) => {
            const inMonth = date.getMonth() === 8
            const hasBirthday = inMonth && birthdayDays.has(date.getDate())
            const isToday = inMonth && date.getDate() === 23
            return (
              <span key={date.toISOString()} className="flex flex-col items-center">
                <span
                  className="grid h-8 w-8 place-items-center rounded-full"
                  style={{
                    background: isToday ? p.primary : hasBirthday ? p.softPink : 'transparent',
                    color: isToday ? p.onPrimary : hasBirthday ? p.accentText : inMonth ? p.textPrimary : p.textSecondary,
                    fontWeight: hasBirthday ? 700 : 400,
                  }}
                >
                  {date.getDate()}
                </span>
                {hasBirthday ? (
                  <span className="mt-0.5 h-1 w-1 rounded-full" style={{ background: p.accent }} />
                ) : null}
              </span>
            )
          })}
        </div>
        <div className="mt-3 text-center">
          <TextButton>Today</TextButton>
        </div>
      </div>
      <section className="mt-6">
        <Label>23 September</Label>
        <div className="mt-3">
          <BirthdayRow person={people[0]} />
        </div>
      </section>
      <BottomNav active="Calendar" />
    </ScreenFrame>
  )
}

export function ContactImportScreen() {
  const selected = contacts.filter((contact) => contact.selected).length
  return (
    <ScreenFrame title="Contact import" sub="Only selected contacts are uploaded">
      <h1 className={typography.display}>Import birthdays</h1>
      <p className="mt-2 text-[13px]" style={{ color: p.textSecondary }}>
        {selected} of {contacts.length} selected · only these are saved to your account
      </p>
      <div className="mt-5 space-y-2">
        {contacts.map((contact) => (
          <Card key={contact.id} className="!py-3">
            <div className="flex items-center justify-between">
              <span>
                <b className="block text-[15px]">{contact.name}</b>
                <span className="text-[12px]" style={{ color: p.textSecondary }}>
                  {contact.day} / {contact.month}
                </span>
              </span>
              <span
                className="grid h-6 w-6 place-items-center rounded-full text-[12px] font-bold"
                style={{
                  background: contact.selected ? p.primary : 'transparent',
                  border: `1px solid ${contact.selected ? p.primary : p.border}`,
                  color: p.onPrimary,
                }}
              >
                {contact.selected ? '✓' : ''}
              </span>
            </div>
          </Card>
        ))}
      </div>
      <div className="mt-5">
        <PrimaryButton>Import {selected} birthdays</PrimaryButton>
      </div>
      <div className="mt-6">
        <Label>Permission state</Label>
        <div className="mt-3">
          <Card>
            <b className="block text-[15px]">🔒 Contact access needed</b>
            <p className="mt-1 text-[12px]" style={{ color: p.textSecondary }}>
              Allow contact access to find birthdays. Only the contacts you pick are saved.
            </p>
          </Card>
        </div>
      </div>
      <div className="mt-6">
        <Label>Duplicate handling</Label>
        <div className="mt-3">
          <Card>
            <b className="block text-[15px]">Sarah Tan</b>
            <span className="text-[12px]" style={{ color: p.textSecondary }}>
              30 September
            </span>
            <p className="mt-2 text-[13px]">This birthday already exists.</p>
            <div className="mt-3 flex justify-end gap-4 text-[13px] font-bold">
              <span style={{ color: p.textSecondary }}>Cancel</span>
              <span style={{ color: p.accentText }}>Update existing</span>
            </div>
          </Card>
        </div>
      </div>
    </ScreenFrame>
  )
}

export function CountdownReferenceScreen() {
  return (
    <ScreenFrame title="Countdown reference" sub="Every relative state in one place">
      <h1 className={typography.display}>Countdowns</h1>
      <div className="mt-5 space-y-2">
        {[0, 1, 3, 7, 14, 30].map((days) => (
          <Card key={days}>
            <div className="flex items-center justify-between">
              <span className="text-[14px]">{reminderLabel(days)}</span>
              <span className="text-[13px] font-bold" style={{ color: p.accentText }}>
                {countdownLabel(days)}
              </span>
            </div>
          </Card>
        ))}
      </div>
    </ScreenFrame>
  )
}
