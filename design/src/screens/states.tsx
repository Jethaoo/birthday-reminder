import { BirthdayRow, Card, Chip, Dialog, EmptyState, ErrorState, Label, NotificationPreview, PrimaryButton, ScreenFrame, Skeleton, Toggle } from '../components'
import { people } from '../data'
import { light } from '../theme'

const p = light

export function EmptyStatesScreen() {
  return (
    <ScreenFrame title="Empty states" sub="No data, no results, all caught up">
      <Label>No birthdays</Label>
      <EmptyState
        title="No birthdays yet"
        message="Add your first birthday and never forget an important date."
        action={<PrimaryButton>Add birthday</PrimaryButton>}
      />
      <div className="mt-4" style={{ borderTop: `1px solid ${p.border}`, paddingTop: 16 }}>
        <Label>No results</Label>
        <EmptyState title="No birthdays found" message="Try another search or filter." />
        <Label>All caught up</Label>
        <EmptyState emoji="🎉" title="You are all caught up!" message="No upcoming birthdays." />
      </div>
    </ScreenFrame>
  )
}

export function LoadingStatesScreen() {
  return (
    <ScreenFrame title="Loading states" sub="Skeletons, not spinners">
      <Label>Birthday list</Label>
      <div className="mt-3">
        <Skeleton rows={4} />
      </div>
      <div className="mt-6">
        <Label>Saving a birthday</Label>
        <div className="mt-3">
          <PrimaryButton disabled>Saving…</PrimaryButton>
        </div>
      </div>
      <div className="mt-6">
        <Label>Contact import progress</Label>
        <div className="mt-3">
          <Skeleton rows={2} />
        </div>
      </div>
      <div className="mt-6">
        <Label>Photo upload</Label>
        <div className="mt-3">
          <Card>
            <div className="flex items-center gap-3">
              <span className="h-10 w-10 animate-pulse rounded-full" style={{ background: p.surfaceVariant }} />
              <span className="text-[13px]" style={{ color: p.textSecondary }}>
                Uploading photo…
              </span>
            </div>
          </Card>
        </div>
      </div>
    </ScreenFrame>
  )
}

export function ErrorStatesScreen() {
  return (
    <ScreenFrame title="Error states" sub="Server, network, validation">
      <ErrorState message="We could not load your birthdays." />
      <div className="mt-4" style={{ borderTop: `1px solid ${p.border}`, paddingTop: 16 }}>
        <Label>No internet connection</Label>
        <div className="mt-3 rounded-[18px] p-4" style={{ background: p.softPink }}>
          <p className="text-[13px] font-semibold" style={{ color: p.accentText }}>
            You are offline. Changes are disabled until you reconnect.
          </p>
          <p className="mt-1 text-[12px]" style={{ color: p.accentText }}>
            Cached data is shown until the connection returns.
          </p>
        </div>
      </div>
      <div className="mt-6">
        <Label>Validation</Label>
        <div className="mt-3 space-y-2">
          <FieldError text="Name is required." />
          <FieldError text="Enter a valid email address." />
          <FieldError text="Password must include at least one letter and one number." />
          <FieldError text="Passwords do not match." />
        </div>
      </div>
      <div className="mt-6">
        <Label>Conflict</Label>
        <div className="mt-3">
          <Dialog
            title="Sarah Tan"
            message="This birthday already exists. Update the existing entry instead?"
            confirmLabel="Update existing"
            destructive={false}
          />
        </div>
      </div>
    </ScreenFrame>
  )
}

function FieldError({ text }: { text: string }) {
  return (
    <div className="rounded-[14px] px-4 py-3" style={{ border: `1px solid ${p.error}`, background: p.surface }}>
      <span className="text-[12px]" style={{ color: p.error }}>
        {text}
      </span>
    </div>
  )
}

export function DialogsScreen() {
  return (
    <ScreenFrame title="Dialogs" sub="Delete, log out, delete account">
      <div className="space-y-4">
        <Dialog
          title="Delete birthday?"
          message="Are you sure you want to delete Sarah Tan's birthday? This action cannot be undone."
        />
        <Dialog
          title="Log out?"
          message="You will need to sign in again to see your birthdays."
          confirmLabel="Log out"
          destructive={false}
        />
        <Dialog
          title="Delete account?"
          message="This permanently removes your account, birthdays, reminders, device registrations and uploaded photos."
          confirmLabel="Delete account"
        />
      </div>
    </ScreenFrame>
  )
}

export function NotificationsScreen() {
  return (
    <ScreenFrame title="Push notifications" sub="Advance, tomorrow, today">
      <div className="space-y-3">
        <NotificationPreview title="🎂 Birthday Reminder" body={"Sarah Tan's birthday is in 7 days.\n30 September"} />
        <NotificationPreview title="🎂 Birthday Tomorrow" body="Sarah Tan's birthday is tomorrow." />
        <NotificationPreview title="🎉 Birthday Today" body="It's Sarah Tan's birthday today!" />
      </div>
      <div className="mt-6">
        <Label>In-app banner while using the app</Label>
        <div className="mt-3 rounded-[14px] p-4" style={{ background: p.primary, color: p.onPrimary }}>
          <p className="text-[13px] font-bold">🎉 It's Sarah Tan's birthday today!</p>
        </div>
      </div>
      <div className="mt-6">
        <Label>Deep link target</Label>
        <div className="mt-3">
          <BirthdayRow person={people[0]} />
        </div>
        <p className="mt-2 text-[12px]" style={{ color: p.textSecondary }}>
          Tapping a notification opens /birthdays/&lt;id&gt;.
        </p>
      </div>
    </ScreenFrame>
  )
}

export function SuccessScreen() {
  return (
    <ScreenFrame title="Feedback" sub="Saved, imported, test notification">
      <Label>Birthday saved</Label>
      <div className="mt-3 space-y-3">
        <Card>
          <div className="flex items-center gap-3">
            <span className="grid h-9 w-9 place-items-center rounded-full" style={{ background: p.softGreen }}>
              ✓
            </span>
            <span>
              <b className="block text-[14px]">Birthday saved</b>
              <span className="text-[12px]" style={{ color: p.textSecondary }}>
                Reminders will be sent in your timezone
              </span>
            </span>
          </div>
        </Card>
        <Card>
          <div className="flex items-center gap-3">
            <span className="grid h-9 w-9 place-items-center rounded-full" style={{ background: p.softGreen }}>
              ✓
            </span>
            <span>
              <b className="block text-[14px]">2 imported · 1 already saved</b>
              <span className="text-[12px]" style={{ color: p.textSecondary }}>
                Duplicates were skipped
              </span>
            </span>
          </div>
        </Card>
        <Card>
          <div className="flex items-center justify-between">
            <span className="text-[14px]">Send a test notification</span>
            <Toggle on />
          </div>
        </Card>
      </div>
      <div className="mt-6 flex flex-wrap gap-2">
        <Chip>Family</Chip>
        <Chip>Friend</Chip>
        <Chip>Colleague</Chip>
        <Chip>Other</Chip>
        <Chip active>Selected</Chip>
      </div>
    </ScreenFrame>
  )
}
