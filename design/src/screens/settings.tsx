import { BottomNav, Card, Chip, Label, PrimaryButton, ScreenFrame, SectionHeader, TextButton, Toggle } from '../components'
import { dark, light, reminderLabel, typography } from '../theme'

const p = light

export function SettingsScreen() {
  return (
    <ScreenFrame title="Settings" sub="Account, notifications, default reminder, appearance">
      <h1 className={typography.display}>Settings</h1>
      <div className="mt-6 space-y-6">
        <section>
          <Label>Account</Label>
          <div className="mt-2">
            <Card>
              <b className="block text-[15px]">Jordan Davis</b>
              <span className="text-[12px]" style={{ color: p.textSecondary }}>
                jordan@example.com
              </span>
              <p className="mt-3 text-[13px] font-bold" style={{ color: p.accentText }}>
                Manage account
              </p>
            </Card>
          </div>
        </section>

        <section>
          <Label>Notifications</Label>
          <div className="mt-2">
            <Card className="!p-0">
              <div className="divide-y" style={{ borderColor: p.border }}>
                {[
                  ['Birthday reminders', true],
                  ["Today's birthdays", true],
                  ['Tomorrow reminders', true],
                  ['Notification sound', true],
                ].map(([label, on]) => (
                  <div key={label as string} className="flex items-center justify-between px-4 py-3.5">
                    <span className="text-[14px]">{label as string}</span>
                    <Toggle on={on as boolean} />
                  </div>
                ))}
              </div>
            </Card>
          </div>
        </section>

        <section>
          <Label>Default reminder</Label>
          <div className="mt-2">
            <Card>
              <div className="flex items-center justify-between">
                <span>
                  <b className="block text-[15px]">{reminderLabel(7)}</b>
                  <span className="text-[12px]" style={{ color: p.textSecondary }}>
                    at 09:00 AM
                  </span>
                </span>
                <span>›</span>
              </div>
            </Card>
          </div>
        </section>

        <section>
          <Label>Appearance</Label>
          <div className="mt-2">
            <Card>
              <div className="flex items-center justify-between">
                <span>
                  <b className="block text-[15px]">Theme</b>
                  <span className="text-[12px]" style={{ color: p.textSecondary }}>
                    System
                  </span>
                </span>
                <span>›</span>
              </div>
            </Card>
          </div>
        </section>

        <section>
          <Label>About</Label>
          <div className="mt-2">
            <Card>
              <div className="flex items-center justify-between">
                <span className="text-[15px]">About Birthday Reminder</span>
                <span>›</span>
              </div>
            </Card>
          </div>
        </section>

        <div className="space-y-3">
          <PrimaryButton>Log out</PrimaryButton>
          <p className="text-center text-[13px] font-bold" style={{ color: p.error }}>
            Delete account
          </p>
        </div>
      </div>
      <BottomNav active="Settings" />
    </ScreenFrame>
  )
}

export function AccountScreen() {
  return (
    <ScreenFrame title="Account" sub="Name, timezone, password, deletion">
      <h1 className={typography.display}>Account</h1>
      <div className="mt-5 space-y-4 text-[14px]">
        {[
          ['Name', 'Jordan Davis'],
          ['Email', 'jordan@example.com'],
          ['Timezone', 'Asia/Kuala_Lumpur'],
        ].map(([label, value]) => (
          <div key={label}>
            <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
              {label}
            </span>
            <div
              className="mt-2 rounded-[14px] px-4 py-3"
              style={{
                background: label === 'Name' ? p.surface : p.surfaceVariant,
                border: `1px solid ${p.border}`,
              }}
            >
              {value}
            </div>
          </div>
        ))}
        <PrimaryButton>Save changes</PrimaryButton>
        <div style={{ border: `1px solid ${p.border}`, borderRadius: '14px' }}>
          <p className="py-3.5 text-center text-[13px] font-bold">Change password</p>
        </div>
      </div>
      <div className="mt-8">
        <p className="text-[16px] font-bold" style={{ color: p.error }}>
          Danger zone
        </p>
        <p className="mt-1.5 text-[12px]" style={{ color: p.textSecondary }}>
          Deleting your account removes your birthdays, reminders, device registrations and photos.
        </p>
        <div className="mt-3" style={{ border: `1px solid ${p.error}`, borderRadius: '14px' }}>
          <p className="py-3.5 text-center text-[13px] font-bold" style={{ color: p.error }}>
            Delete account
          </p>
        </div>
      </div>
    </ScreenFrame>
  )
}

export function NotificationSettingsScreen() {
  return (
    <ScreenFrame title="Notification settings" sub="Default reminder, delivery, test push">
      <h1 className={typography.display}>Notifications</h1>
      <div className="mt-5 space-y-4">
        <div>
          <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
            Default reminder
          </span>
          <div
            className="mt-2 rounded-[14px] px-4 py-3 text-[14px]"
            style={{ background: p.surface, border: `1px solid ${p.border}` }}
          >
            {reminderLabel(7)} ▾
          </div>
        </div>
        <div>
          <span className="text-[12px] font-semibold" style={{ color: p.textSecondary }}>
            Time
          </span>
          <div
            className="mt-2 flex justify-between rounded-[14px] px-4 py-3 text-[14px]"
            style={{ background: p.surface, border: `1px solid ${p.border}` }}
          >
            9:00 AM <span style={{ color: p.textSecondary }}>🕘</span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          {[0, 1, 3, 7, 14, 30].map((days) => (
            <Chip key={days} active={days === 7}>
              {reminderLabel(days)}
            </Chip>
          ))}
        </div>
        <Card className="!p-0">
          <div className="divide-y" style={{ borderColor: p.border }}>
            {[
              ['Birthday reminders', true],
              ['Notification sound', true],
            ].map(([label, on]) => (
              <div key={label as string} className="flex items-center justify-between px-4 py-3.5">
                <span className="text-[14px]">{label as string}</span>
                <Toggle on={on as boolean} />
              </div>
            ))}
          </div>
        </Card>
        <div style={{ border: `1px solid ${p.border}`, borderRadius: '14px' }}>
          <p className="py-3.5 text-center text-[13px] font-bold">Send a test notification</p>
        </div>
        <p className="text-[11px]" style={{ color: p.textSecondary }}>
          Test notifications are only available outside production.
        </p>
      </div>
    </ScreenFrame>
  )
}

export function AppearanceScreen() {
  return (
    <ScreenFrame title="Appearance" sub="System, light or dark">
      <h1 className={typography.display}>Appearance</h1>
      <div className="mt-5">
        <Card className="!p-0">
          <div className="divide-y" style={{ borderColor: p.border }}>
            {[
              ['System', 'Match your device setting', false],
              ['Light', 'Always use the light theme', true],
              ['Dark', 'Always use the dark theme', false],
            ].map(([label, sub, selected]) => (
              <div key={label as string} className="flex items-center justify-between px-4 py-3.5">
                <span>
                  <b className="block text-[15px]">{label as string}</b>
                  <span className="text-[12px]" style={{ color: p.textSecondary }}>
                    {sub as string}
                  </span>
                </span>
                <span style={{ color: selected ? p.accentText : p.textSecondary }}>
                  {selected ? '◉' : '○'}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <div className="mt-6 grid grid-cols-2 gap-3">
        {[
          ['Light', light],
          ['Dark', dark],
        ].map(([label, palette]) => {
          const swatches = palette as typeof light
          return (
            <div key={label as string}>
              <Label>{label as string}</Label>
              <div className="mt-2 grid grid-cols-3 gap-2">
                {[swatches.background, swatches.surface, swatches.surfaceVariant, swatches.primary, swatches.accent, swatches.softGreen].map(
                  (color) => (
                    <span
                      key={color}
                      className="h-8 rounded-[10px]"
                      style={{ background: color, border: `1px solid ${light.border}` }}
                    />
                  ),
                )}
              </div>
            </div>
          )
        })}
      </div>
    </ScreenFrame>
  )
}

export function AboutScreen() {
  return (
    <ScreenFrame title="About" sub="Version, privacy, terms">
      <span className="text-[40px]">🎂</span>
      <h1 className={`mt-3 ${typography.display} text-[26px]`}>Birthday Reminder</h1>
      <p className="mt-1 text-[12px]" style={{ color: p.textSecondary }}>
        Version 1.0.0
      </p>
      <p className="mt-5 text-[14px]" style={{ color: p.textSecondary }}>
        Save the birthdays that matter, get a reminder before the day and keep gift ideas in one place. Your birthdays are
        stored in your account so they follow you to every device you sign in on.
      </p>
      <div className="mt-6">
        <Card className="!p-0">
          <div className="divide-y" style={{ borderColor: p.border }}>
            {[
              ['Privacy policy', 'How your data is handled'],
              ['Terms of service', 'Rules for using the app'],
            ].map(([title, sub]) => (
              <div key={title} className="px-4 py-3.5">
                <b className="block text-[15px]">{title}</b>
                <span className="text-[12px]" style={{ color: p.textSecondary }}>
                  {sub}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <p className="mt-4 text-[12px]" style={{ color: p.textSecondary }}>
        Reminders are delivered by push notification. Times are interpreted in your timezone, and 29 February birthdays
        are celebrated on 28 February in non-leap years.
      </p>
      <div className="mt-6">
        <SectionHeader title="Design tokens" />
        <div className="space-y-2 text-[12px]">
          {Object.entries(light)
            .filter(([key]) => key !== 'avatarTints')
            .map(([key, value]) => (
              <div key={key} className="flex items-center justify-between">
                <span className="font-mono">{key}</span>
                <span className="flex items-center gap-2">
                  <span className="h-4 w-4 rounded" style={{ background: value as string, border: `1px solid ${p.border}` }} />
                  <span className="font-mono">{value as string}</span>
                </span>
              </div>
            ))}
        </div>
      </div>
      <div className="mt-4">
        <TextButton>Back</TextButton>
      </div>
    </ScreenFrame>
  )
}
