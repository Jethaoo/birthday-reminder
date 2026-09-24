import type { ReactNode } from 'react'
import { countdownLabel, light, radius, reminderLabel, typography, type Palette } from './theme'
import type { Person } from './data'

export const tintOf = (person: Pick<Person, 'tint'>, palette: Palette = light) =>
  palette.avatarTints[person.tint % palette.avatarTints.length]

export function Avatar({
  person,
  size = 48,
  palette = light,
}: {
  person: Pick<Person, 'initials' | 'tint'>
  size?: number
  palette?: Palette
}) {
  return (
    <span
      className="grid shrink-0 place-items-center rounded-full font-semibold"
      style={{
        width: size,
        height: size,
        background: tintOf(person, palette),
        color: palette.textPrimary,
        fontSize: Math.round(size * 0.32),
      }}
      aria-hidden="true"
    >
      {person.initials}
    </span>
  )
}

export function Pill({ children, palette = light, tone = 'pink' }: { children: ReactNode; palette?: Palette; tone?: 'pink' | 'green' }) {
  return (
    <span
      className="rounded-full px-3 py-1 text-[11px] font-bold"
      style={{
        background: tone === 'pink' ? palette.softPink : palette.softGreen,
        color: tone === 'pink' ? palette.accentText : palette.textPrimary,
      }}
    >
      {children}
    </span>
  )
}

export function Card({
  children,
  palette = light,
  className = '',
}: {
  children: ReactNode
  palette?: Palette
  className?: string
}) {
  return (
    <div
      className={`p-4 ${className}`}
      style={{ background: palette.surface, border: `1px solid ${palette.border}`, borderRadius: radius.card }}
    >
      {children}
    </div>
  )
}

export function Label({ children, palette = light }: { children: ReactNode; palette?: Palette }) {
  return (
    <p className={typography.label} style={{ color: palette.textSecondary }}>
      {children}
    </p>
  )
}

export function PrimaryButton({
  children,
  palette = light,
  full = true,
  onClick,
  type = 'button',
  disabled,
}: {
  children: ReactNode
  palette?: Palette
  full?: boolean
  onClick?: () => void
  type?: 'button' | 'submit'
  disabled?: boolean
}) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`${full ? 'w-full' : ''} rounded-[14px] px-5 py-3.5 text-[14px] font-bold transition disabled:opacity-50`}
      style={{ background: palette.primary, color: palette.onPrimary }}
    >
      {children}
    </button>
  )
}

export function SecondaryButton({
  children,
  palette = light,
  full = true,
  onClick,
}: {
  children: ReactNode
  palette?: Palette
  full?: boolean
  onClick?: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`${full ? 'w-full' : ''} rounded-[14px] px-5 py-3.5 text-[14px] font-bold`}
      style={{ border: `1px solid ${palette.border}`, color: palette.textPrimary, background: 'transparent' }}
    >
      {children}
    </button>
  )
}

export function TextButton({ children, palette = light, onClick }: { children: ReactNode; palette?: Palette; onClick?: () => void }) {
  return (
    <button type="button" onClick={onClick} className="text-[13px] font-bold" style={{ color: palette.accentText }}>
      {children}
    </button>
  )
}

export function Field({
  label,
  value,
  hint,
  palette = light,
  type = 'text',
  helper,
  readOnly,
}: {
  label: string
  value?: string
  hint?: string
  palette?: Palette
  type?: string
  helper?: string
  readOnly?: boolean
}) {
  return (
    <label className="block">
      <span className="text-[12px] font-semibold" style={{ color: palette.textSecondary }}>
        {label}
      </span>
      <input
        type={type}
        defaultValue={value}
        placeholder={hint}
        readOnly={readOnly}
        className="mt-2 w-full rounded-[14px] px-4 py-3 text-[14px] outline-none"
        style={{
          background: readOnly ? palette.surfaceVariant : palette.surface,
          border: `1px solid ${palette.border}`,
          color: palette.textPrimary,
        }}
      />
      {helper ? (
        <span className="mt-1 block text-[11px]" style={{ color: palette.textSecondary }}>
          {helper}
        </span>
      ) : null}
    </label>
  )
}

export function Toggle({ on, palette = light, label }: { on: boolean; palette?: Palette; label?: string }) {
  return (
    <span className="flex items-center gap-2">
      {label ? <span className="text-[13px]">{label}</span> : null}
      <span
        className="flex h-6 w-11 items-center rounded-full p-0.5"
        style={{ background: on ? palette.primary : palette.border }}
        role="switch"
        aria-checked={on}
      >
        <span
          className="h-5 w-5 rounded-full bg-white shadow transition"
          style={{ transform: on ? 'translateX(20px)' : 'none' }}
        />
      </span>
    </span>
  )
}

export function ScreenFrame({
  title,
  children,
  palette = light,
  dark = false,
  sub,
}: {
  title: string
  children: ReactNode
  palette?: Palette
  dark?: boolean
  sub?: string
}) {
  return (
    <figure className="w-[390px] shrink-0">
      <figcaption className="mb-2">
        <span className="block text-[13px] font-bold" style={{ color: light.textPrimary }}>
          {title}
        </span>
        {sub ? (
          <span className="block text-[11px]" style={{ color: light.textSecondary }}>
            {sub}
          </span>
        ) : null}
      </figcaption>
      <div
        className={dark ? 'dark' : undefined}
        style={{ background: palette.background, border: `1px solid ${light.border}` }}
      >
        <div className="h-[780px] overflow-y-auto px-5 py-5" style={{ color: palette.textPrimary }}>
          {children}
        </div>
      </div>
    </figure>
  )
}

export function BottomNav({ active, palette = light }: { active: string; palette?: Palette }) {
  const items = ['Home', 'Birthdays', 'Calendar', 'Settings']
  return (
    <nav
      className="mt-6 flex items-center justify-around rounded-[28px] px-2 py-2"
      style={{ background: palette.surface, border: `1px solid ${palette.border}` }}
    >
      {items.map((item) => (
        <span
          key={item}
          className="grid min-w-[66px] place-items-center gap-1 rounded-[18px] px-2 py-2 text-[10px] font-bold"
          style={{
            color: active === item ? palette.textPrimary : palette.textSecondary,
            background: active === item ? palette.surfaceVariant : 'transparent',
          }}
        >
          <span
            className="h-2.5 w-2.5 rounded-full"
            style={{ background: active === item ? palette.primary : palette.border }}
          />
          {item}
        </span>
      ))}
    </nav>
  )
}

export function SectionHeader({
  title,
  trailing,
  palette = light,
}: {
  title: string
  trailing?: ReactNode
  palette?: Palette
}) {
  return (
    <div className="mb-3 flex items-center justify-between">
      <h2 className={typography.title} style={{ color: palette.textPrimary }}>
        {title}
      </h2>
      {trailing}
    </div>
  )
}

export function BirthdayRow({
  person,
  palette = light,
  dark = false,
}: {
  person: Person
  palette?: Palette
  dark?: boolean
}) {
  return (
    <div
      className="flex items-center gap-3 p-3.5"
      style={{ background: palette.surface, border: `1px solid ${palette.border}`, borderRadius: '18px' }}
    >
      <Avatar person={person} palette={palette} />
      <span className="flex-1">
        <b className="block text-[15px]" style={{ color: palette.textPrimary }}>
          {person.name}
        </b>
        <span className="text-[12px]" style={{ color: palette.textSecondary }}>
          {person.day} {person.monthName} · {person.relationship}
        </span>
      </span>
      <span className="text-[13px] font-bold" style={{ color: palette.accentText }}>
        {countdownLabel(person.days)}
      </span>
    </div>
  )
}

export function TodayCard({ person, palette = light }: { person: Person; palette?: Palette }) {
  return (
    <div className="rounded-[24px] p-5" style={{ background: palette.heroCard, color: palette.heroCardText }}>
      <div className="flex items-start justify-between">
        <Avatar person={person} palette={palette} />
        {person.birthYear ? (
          <span
            className="rounded-full px-3 py-1 text-[12px] font-semibold"
            style={{ background: 'rgba(255,255,255,.15)' }}
          >
            Turning {new Date().getFullYear() - person.birthYear}
          </span>
        ) : null}
      </div>
      <p className="mt-5 text-[24px] font-bold tracking-[-0.8px]">{person.name}</p>
      <p className="mt-1 text-[14px] opacity-70">Their birthday is today</p>
      <span
        className="mt-5 inline-flex items-center gap-2 rounded-full px-4 py-2.5 text-[13px] font-bold"
        style={{ background: palette.accent, color: '#fff' }}
      >
        View details →
      </span>
    </div>
  )
}

export function MonthlySummaryCard({ palette = light }: { palette?: Palette }) {
  const stats = [
    { value: '5', label: 'birthdays' },
    { value: '2', label: 'upcoming' },
    { value: '1', label: 'today' },
  ]
  return (
    <div className="rounded-[22px] p-5" style={{ background: palette.softGreen }}>
      <p className={typography.label} style={{ color: palette.textSecondary }}>
        September
      </p>
      <p className="mt-2 text-[22px] font-bold tracking-[-0.6px]" style={{ color: palette.textPrimary }}>
        A month to celebrate
      </p>
      <div className="mt-5 grid grid-cols-3 pt-4 text-center" style={{ borderTop: `1px solid ${palette.border}` }}>
        {stats.map((stat, index) => (
          <div key={stat.label} style={{ borderLeft: index ? `1px solid ${palette.border}` : undefined }}>
            <b className="block text-[18px]" style={{ color: palette.textPrimary }}>
              {stat.value}
            </b>
            <span className="text-[11px]" style={{ color: palette.textSecondary }}>
              {stat.label}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}

export function EmptyState({
  emoji = '🎂',
  title,
  message,
  palette = light,
  action,
}: {
  emoji?: string
  title: string
  message?: string
  palette?: Palette
  action?: ReactNode
}) {
  return (
    <div className="flex flex-col items-center px-6 py-10 text-center">
      <span className="text-[40px]">{emoji}</span>
      <p className="mt-4 text-[16px] font-bold" style={{ color: palette.textPrimary }}>
        {title}
      </p>
      {message ? (
        <p className="mt-2 text-[13px]" style={{ color: palette.textSecondary }}>
          {message}
        </p>
      ) : null}
      {action ? <div className="mt-5 w-full">{action}</div> : null}
    </div>
  )
}

export function ErrorState({
  palette = light,
  title = 'Something went wrong',
  message,
}: {
  palette?: Palette
  title?: string
  message: string
}) {
  return (
    <div className="flex flex-col items-center px-6 py-10 text-center">
      <span className="text-[36px]">😕</span>
      <p className="mt-4 text-[16px] font-bold" style={{ color: palette.textPrimary }}>
        {title}
      </p>
      <p className="mt-2 text-[13px]" style={{ color: palette.textSecondary }}>
        {message}
      </p>
      <div className="mt-5 w-full">
        <PrimaryButton palette={palette}>Try again</PrimaryButton>
      </div>
    </div>
  )
}

export function Skeleton({ rows = 4, palette = light }: { rows?: number; palette?: Palette }) {
  return (
    <div className="space-y-3">
      {Array.from({ length: rows }).map((_, index) => (
        <div
          key={index}
          className="h-[72px] animate-pulse rounded-[22px]"
          style={{ background: palette.surfaceVariant }}
        />
      ))}
    </div>
  )
}

export function Dialog({
  title,
  message,
  confirmLabel = 'Delete',
  cancelLabel = 'Cancel',
  palette = light,
  destructive = true,
}: {
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  palette?: Palette
  destructive?: boolean
}) {
  return (
    <div
      className="rounded-[22px] p-5"
      style={{ background: palette.surface, border: `1px solid ${palette.border}` }}
    >
      <p className="text-[16px] font-bold" style={{ color: palette.textPrimary }}>
        {title}
      </p>
      <p className="mt-2 text-[13px]" style={{ color: palette.textSecondary }}>
        {message}
      </p>
      <div className="mt-5 flex justify-end gap-4 text-[13px] font-bold">
        <button style={{ color: palette.textSecondary }}>{cancelLabel}</button>
        <button style={{ color: destructive ? palette.error : palette.primary }}>{confirmLabel}</button>
      </div>
    </div>
  )
}

export function NotificationPreview({
  title,
  body,
  palette = light,
}: {
  title: string
  body: string
  palette?: Palette
}) {
  return (
    <div
      className="flex gap-3 rounded-[18px] p-4"
      style={{ background: palette.surface, border: `1px solid ${palette.border}` }}
    >
      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-[12px] text-[18px]" style={{ background: palette.softPink }}>
        🎂
      </span>
      <span>
        <b className="block text-[13px]" style={{ color: palette.textPrimary }}>
          {title}
        </b>
        <span className="text-[12px] whitespace-pre-line" style={{ color: palette.textSecondary }}>
          {body}
        </span>
      </span>
    </div>
  )
}

export function ReminderRow({ reminder, palette = light }: { reminder: Person['reminders'][number]; palette?: Palette }) {
  return (
    <div className="flex items-center justify-between py-2">
      <span>
        <b className="block text-[14px]" style={{ color: palette.textPrimary }}>
          {reminderLabel(reminder.daysBefore)}
        </b>
        <span className="text-[12px]" style={{ color: palette.textSecondary }}>
          {reminder.time}
        </span>
      </span>
      <Toggle on={reminder.enabled} palette={palette} />
    </div>
  )
}

export function Chip({ children, palette = light, active = false }: { children: ReactNode; palette?: Palette; active?: boolean }) {
  return (
    <span
      className="whitespace-nowrap rounded-full px-3.5 py-2 text-[12px] font-bold"
      style={{
        background: active ? palette.primary : palette.surface,
        color: active ? palette.onPrimary : palette.textSecondary,
        border: `1px solid ${active ? palette.primary : palette.border}`,
      }}
    >
      {children}
    </span>
  )
}
