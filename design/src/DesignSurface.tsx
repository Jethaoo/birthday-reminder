import type { ReactNode } from 'react'
import {
  Avatar,
  BirthdayRow,
  BottomNav,
  Card,
  Chip,
  Dialog,
  Label,
  MonthlySummaryCard,
  NotificationPreview,
  Pill,
  PrimaryButton,
  ReminderRow,
  ScreenFrame,
  SectionHeader,
  Skeleton,
  TextButton,
  TodayCard,
  Toggle,
} from './components'
import { people, todayPeople, upcomingPeople } from './data'
import {
  AddBirthdayScreen,
  BirthdaysNoResultsScreen,
  BirthdaysScreen,
  BirthdayDetailsScreen,
  CalendarScreen,
  ContactImportScreen,
  CountdownReferenceScreen,
  EditBirthdayScreen,
  HomeEmptyScreen,
  HomeScreen,
  ReminderEditorScreen,
} from './screens/main'
import {
  ForgotPasswordScreen,
  LoginScreen,
  RegisterScreen,
  ResetPasswordScreen,
  WelcomeScreen,
} from './screens/auth'
import {
  AboutScreen,
  AccountScreen,
  AppearanceScreen,
  NotificationSettingsScreen,
  SettingsScreen,
} from './screens/settings'
import {
  DialogsScreen,
  EmptyStatesScreen,
  ErrorStatesScreen,
  LoadingStatesScreen,
  NotificationsScreen,
  SuccessScreen,
} from './screens/states'
import { dark, light, radius, typography } from './theme'

function Section({
  id,
  title,
  description,
  children,
}: {
  id: string
  title: string
  description: string
  children: ReactNode
}) {
  return (
    <section id={id} className="border-t border-[#E5E5DC] px-8 py-10 first:border-t-0">
      <header className="mb-6 max-w-3xl">
        <h2 className="font-[Fraunces] text-[26px] font-bold tracking-[-0.8px] text-[#243029]">{title}</h2>
        <p className="mt-2 text-[14px] text-[#7C857F]">{description}</p>
      </header>
      <div className="flex flex-wrap gap-8">{children}</div>
    </section>
  )
}

function TokenGrid() {
  const lightEntries = Object.entries(light).filter(([key]) => key !== 'avatarTints') as [string, string][]
  const darkEntries = Object.entries(dark).filter(([key]) => key !== 'avatarTints') as [string, string][]

  return (
    <div className="flex flex-wrap gap-8">
      <div className="w-[420px]">
        <Label>Light tokens</Label>
        <div className="mt-3 space-y-2">
          {lightEntries.map(([key, value]) => (
            <div key={key} className="flex items-center justify-between text-[12px] text-[#243029]">
              <span className="font-mono">{key}</span>
              <span className="flex items-center gap-2">
                <span className="h-4 w-4 rounded" style={{ background: value, border: '1px solid #E5E5DC' }} />
                <span className="font-mono">{value}</span>
              </span>
            </div>
          ))}
        </div>
      </div>
      <div className="w-[420px]">
        <Label>Dark tokens</Label>
        <div className="mt-3 space-y-2">
          {darkEntries.map(([key, value]) => (
            <div key={key} className="flex items-center justify-between text-[12px] text-[#243029]">
              <span className="font-mono">{key}</span>
              <span className="flex items-center gap-2">
                <span className="h-4 w-4 rounded" style={{ background: value, border: '1px solid #E5E5DC' }} />
                <span className="font-mono">{value}</span>
              </span>
            </div>
          ))}
        </div>
      </div>
      <div className="w-[420px]">
        <Label>Avatar tints</Label>
        <div className="mt-3 flex gap-3">
          {light.avatarTints.map((tint) => (
            <span key={tint} className="h-12 w-12 rounded-full" style={{ background: tint, border: '1px solid #E5E5DC' }} />
          ))}
        </div>
        <div className="mt-5">
          <Label>Radii</Label>
          <div className="mt-3 space-y-1 font-mono text-[12px] text-[#243029]">
            {Object.entries(radius).map(([key, value]) => (
              <div key={key}>
                {key}: {value}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

function ComponentSheet() {
  return (
    <ScreenFrame title="Components" sub="Buttons, fields, chips, cards, feedback">
      <h1 className={typography.display}>Components</h1>
      <div className="mt-5 space-y-4">
        <PrimaryButton>Primary button</PrimaryButton>
        <div style={{ border: `1px solid ${light.border}`, borderRadius: radius.field }}>
          <p className="py-3.5 text-center text-[14px] font-bold">Secondary button</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <TextButton>Text button</TextButton>
          <Chip active>Selected chip</Chip>
          <Chip>Default chip</Chip>
        </div>
        <label className="block">
          <span className="text-[12px] font-semibold text-[#7C857F]">Text field</span>
          <input
            className="mt-2 w-full rounded-[14px] px-4 py-3 text-[14px] outline-none"
            style={{ background: light.surface, border: `1px solid ${light.border}` }}
            placeholder="e.g. Sarah Tan"
          />
        </label>
        <Card>
          <div className="flex items-center justify-between">
            <span className="text-[14px]">Toggle</span>
            <Toggle on />
          </div>
        </Card>
        <Card>
          <Label>Card + label</Label>
          <p className="mt-2 text-[14px]">Body copy inside a card surface.</p>
        </Card>
        <div className="flex items-center gap-3">
          <Pill>1 today</Pill>
          <Pill tone="green">Upcoming</Pill>
          <Avatar person={{ initials: 'ST', tint: 0 }} />
        </div>
        <SectionHeader title="Section header" trailing={<TextButton>View all</TextButton>} />
        <Skeleton rows={2} />
        <Dialog title="Dialog" message="Used for confirmations and duplicate birthdays." />
        <NotificationPreview title="🎂 Birthday Reminder" body={"Sarah Tan's birthday is in 7 days.\n30 September"} />
      </div>
    </ScreenFrame>
  )
}

function DarkHomePreview() {
  const person = todayPeople[0] ?? people[0]
  return (
    <ScreenFrame title="Home" sub="Dark theme" palette={dark} dark>
      <header className="flex items-start justify-between">
        <div>
          <p className="text-[13px] font-semibold" style={{ color: dark.textSecondary }}>
            Tuesday, 23 September
          </p>
          <h1 className={`mt-1 ${typography.display}`} style={{ color: dark.textPrimary }}>
            Good morning 👋
          </h1>
        </div>
        <span
          className="grid h-11 w-11 place-items-center rounded-full text-[13px] font-bold"
          style={{ background: dark.primary, color: dark.onPrimary }}
        >
          JD
        </span>
      </header>
      <section className="mt-8">
        <SectionHeader title="Today's birthdays" palette={dark} trailing={<Pill palette={dark}>1 today</Pill>} />
        <TodayCard person={person} palette={dark} />
      </section>
      <section className="mt-8">
        <SectionHeader title="Coming up" palette={dark} trailing={<TextButton palette={dark}>View all</TextButton>} />
        <div className="space-y-2">
          {upcomingPeople.slice(0, 3).map((upcoming) => (
            <BirthdayRow key={upcoming.id} person={upcoming} palette={dark} dark />
          ))}
        </div>
      </section>
      <section className="mt-6">
        <MonthlySummaryCard palette={dark} />
      </section>
      <BottomNav active="Home" palette={dark} />
    </ScreenFrame>
  )
}

function DarkDetailsPreview() {
  const person = people[0]
  return (
    <ScreenFrame title="Birthday details" sub="Dark theme" palette={dark} dark>
      <div className="text-center">
        <div className="flex justify-center">
          <Avatar person={person} palette={dark} size={88} />
        </div>
        <h1 className={`mt-4 ${typography.display}`}>{person.name}</h1>
        <p className="mt-1 text-[14px]" style={{ color: dark.textSecondary }}>
          {person.day} {person.monthName} · {person.relationship}
        </p>
        <div className="mt-3 flex justify-center">
          <Pill palette={dark}>🎂 Today</Pill>
        </div>
      </div>
      <div className="mt-6 space-y-3">
        <Card palette={dark}>
          <Label palette={dark}>Reminders</Label>
          <div className="mt-2">
            {person.reminders.slice(0, 2).map((reminder) => (
              <ReminderRow key={reminder.id} reminder={reminder} palette={dark} />
            ))}
          </div>
        </Card>
        <Card palette={dark}>
          <Label palette={dark}>Gift ideas</Label>
          <div className="mt-3 flex flex-wrap gap-2">
            {person.giftIdeas.map((idea) => (
              <span
                key={idea}
                className="rounded-full px-3 py-1.5 text-[12px] font-semibold"
                style={{ background: dark.surfaceVariant, color: dark.textPrimary }}
              >
                {idea}
              </span>
            ))}
          </div>
        </Card>
        <Card palette={dark}>
          <Label palette={dark}>Notes</Label>
          <p className="mt-2 text-[14px]">{person.notes}</p>
        </Card>
      </div>
    </ScreenFrame>
  )
}

function FlowsSheet() {
  const flows: { title: string; steps: string[] }[] = [
    {
      title: '1. First-time user',
      steps: ['Welcome', 'Create account', 'Home', 'Add birthday', 'Save', 'Birthday on Home'],
    },
    {
      title: '2. Add birthday',
      steps: ['Home', 'Add button', 'Add birthday', 'Details', 'Save', 'Birthday details'],
    },
    {
      title: '3. Reminders',
      steps: ['Birthday details', 'Reminders', 'Add reminder', 'Pick day and time', 'Saved'],
    },
    {
      title: '4. Notification',
      steps: ['Cron engine', 'FCM push', 'Android notification', 'Tap', 'Birthday details'],
    },
    { title: '5. Calendar', steps: ['Calendar', 'Select date', 'Birthday list', 'Birthday details'] },
    {
      title: '6. Contact import',
      steps: ['Add birthday', 'Import from contacts', 'Select contacts', 'Import', 'Birthday list'],
    },
  ]

  return (
    <div className="flex flex-wrap gap-8">
      {flows.map((flow) => (
        <div key={flow.title} className="w-[260px]">
          <h3 className="text-[15px] font-bold text-[#243029]">{flow.title}</h3>
          <ol className="mt-3 space-y-2">
            {flow.steps.map((step, index) => (
              <li key={step} className="flex items-center gap-3 text-[13px] text-[#243029]">
                <span
                  className="grid h-6 w-6 place-items-center rounded-full text-[11px] font-bold"
                  style={{ background: light.surfaceVariant }}
                >
                  {index + 1}
                </span>
                {step}
              </li>
            ))}
          </ol>
        </div>
      ))}
    </div>
  )
}

const navItems: [string, string][] = [
  ['design-system', 'Design system'],
  ['auth', 'Authentication'],
  ['main', 'Main app'],
  ['birthdays', 'Birthday management'],
  ['settings', 'Settings'],
  ['states', 'States'],
  ['dark', 'Dark theme'],
  ['flows', 'Flows'],
]

export default function DesignSurface() {
  return (
    <main className="min-h-screen bg-[#F8F8F4]">
      <header className="px-8 pt-10">
        <p className="text-[12px] font-bold tracking-[0.12em] text-[#7C857F] uppercase">
          Birthday Reminder · V1 design surface
        </p>
        <h1 className="mt-3 font-[Fraunces] text-[38px] font-bold tracking-[-1.4px] text-[#243029]">
          Every screen, state and token
        </h1>
        <p className="mt-3 max-w-3xl text-[15px] text-[#7C857F]">
          The canonical visual language for the Flutter Android app: four tabs, the birthday lifecycle, reminders,
          contact import, settings and every state. AI birthday wishes are excluded from V1.
        </p>
        <nav className="mt-6 flex flex-wrap gap-3 text-[13px] font-bold text-[#243029]">
          {navItems.map(([id, label]) => (
            <a key={id} href={`#${id}`} className="rounded-full border border-[#E5E5DC] bg-white px-3.5 py-2">
              {label}
            </a>
          ))}
        </nav>
      </header>

      <Section
        id="design-system"
        title="Design system"
        description="Colour tokens, typography, radii and the reusable component set, shown in light and dark."
      >
        <TokenGrid />
        <ComponentSheet />
      </Section>

      <Section
        id="auth"
        title="Authentication"
        description="Welcome, sign in, create account and password reset. Validation is inline, and reset responses never reveal whether an account exists."
      >
        <WelcomeScreen />
        <LoginScreen />
        <RegisterScreen />
        <ForgotPasswordScreen />
        <ResetPasswordScreen />
      </Section>

      <Section
        id="main"
        title="Main app"
        description="Home, Birthdays and Calendar, plus the countdown reference used across the app."
      >
        <HomeScreen />
        <HomeEmptyScreen />
        <BirthdaysScreen />
        <BirthdaysNoResultsScreen />
        <CalendarScreen />
        <CountdownReferenceScreen />
      </Section>

      <Section
        id="birthdays"
        title="Birthday management"
        description="Details, add, edit, reminder editing and contact import."
      >
        <BirthdayDetailsScreen />
        <AddBirthdayScreen />
        <EditBirthdayScreen />
        <ReminderEditorScreen />
        <ContactImportScreen />
      </Section>

      <Section
        id="settings"
        title="Settings"
        description="Account, notifications, default reminder, appearance and about."
      >
        <SettingsScreen />
        <AccountScreen />
        <NotificationSettingsScreen />
        <AppearanceScreen />
        <AboutScreen />
      </Section>

      <Section
        id="states"
        title="States"
        description="Empty, loading, error, offline, dialogs, notifications and feedback."
      >
        <EmptyStatesScreen />
        <LoadingStatesScreen />
        <ErrorStatesScreen />
        <DialogsScreen />
        <NotificationsScreen />
        <SuccessScreen />
      </Section>

      <Section
        id="dark"
        title="Dark theme"
        description="The same screens rendered with the dark token set at the same density."
      >
        <DarkHomePreview />
        <DarkDetailsPreview />
      </Section>

      <Section id="flows" title="Flows" description="The six journeys the app must support in V1.">
        <FlowsSheet />
      </Section>

      <footer className="px-8 py-10 text-[12px] text-[#7C857F]">
        Reference implementation of the visual language. The shipping app is the Flutter project in{' '}
        <span className="font-mono">app/</span>.
      </footer>
    </main>
  )
}
