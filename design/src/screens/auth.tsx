import { light, typography } from '../theme'
import { Field, PrimaryButton, ScreenFrame, SecondaryButton, TextButton } from '../components'

const p = light

export function WelcomeScreen() {
  return (
    <ScreenFrame title="Welcome" sub="First launch, before sign in">
      <div className="flex h-full flex-col justify-between">
        <div>
          <span
            className="grid h-[72px] w-[72px] place-items-center rounded-[24px] text-[34px]"
            style={{ background: p.softPink }}
          >
            🎂
          </span>
          <h1 className={`mt-7 ${typography.display} text-[36px]`}>{'Remember Every\nBirthday'}</h1>
          <p className="mt-3 text-[16px]" style={{ color: p.textSecondary }}>
            Never forget an important birthday again. Save the dates, get reminders before the day and keep gift ideas in one place.
          </p>
        </div>
        <div className="space-y-3">
          <PrimaryButton>Get started</PrimaryButton>
          <SecondaryButton>Sign in</SecondaryButton>
        </div>
      </div>
    </ScreenFrame>
  )
}

export function LoginScreen() {
  return (
    <ScreenFrame title="Sign in" sub="Email + password, forgot password link">
      <h1 className={`${typography.display} text-[30px]`}>Welcome back</h1>
      <p className="mt-1.5 text-[14px]" style={{ color: p.textSecondary }}>
        Sign in to see your upcoming birthdays.
      </p>
      <div className="mt-7 space-y-4">
        <Field label="Email" value="jordan@example.com" palette={p} />
        <Field label="Password" value="••••••••••" type="password" palette={p} />
        <div className="text-right">
          <TextButton>Forgot password?</TextButton>
        </div>
        <PrimaryButton>Sign in</PrimaryButton>
      </div>
      <p className="mt-6 text-center text-[13px]" style={{ color: p.textSecondary }}>
        New here? <TextButton>Create account</TextButton>
      </p>
      <div className="mt-6">
        <Field label="Validation" hint="Enter a valid email address." helper="Shown inline under the field" palette={p} />
      </div>
    </ScreenFrame>
  )
}

export function RegisterScreen() {
  return (
    <ScreenFrame title="Create account" sub="Name, email, password, confirm">
      <h1 className={`${typography.display} text-[30px]`}>Create account</h1>
      <p className="mt-1.5 text-[14px]" style={{ color: p.textSecondary }}>
        Your birthdays are stored securely so they are on every device you sign in to.
      </p>
      <div className="mt-7 space-y-4">
        <Field label="Name" value="Jordan Davis" palette={p} />
        <Field label="Email" value="jordan@example.com" palette={p} />
        <Field
          label="Password"
          type="password"
          value="••••••••••"
          helper="At least 8 characters with a letter and a number"
          palette={p}
        />
        <Field label="Confirm password" type="password" value="••••••••••" palette={p} />
        <PrimaryButton>Create account</PrimaryButton>
      </div>
      <p className="mt-6 text-center text-[13px]" style={{ color: p.textSecondary }}>
        Already have an account? <TextButton>Sign in</TextButton>
      </p>
    </ScreenFrame>
  )
}

export function ForgotPasswordScreen() {
  return (
    <ScreenFrame title="Forgot password" sub="Neutral response, no account enumeration">
      <h1 className={`${typography.display} text-[28px]`}>Forgot password</h1>
      <p className="mt-2 text-[14px]" style={{ color: p.textSecondary }}>
        Enter the email on your account and we will send a reset link.
      </p>
      <div className="mt-6 space-y-4">
        <Field label="Email" value="jordan@example.com" palette={p} />
        <PrimaryButton>Send reset link</PrimaryButton>
      </div>
      <div className="mt-8 rounded-[22px] p-4" style={{ background: p.softGreen }}>
        <p className="text-[13px]">
          If that email is registered, a reset link is on its way. It expires in 60 minutes and can only be used once.
        </p>
      </div>
    </ScreenFrame>
  )
}

export function ResetPasswordScreen() {
  return (
    <ScreenFrame title="Reset password" sub="Opened from the emailed link">
      <h1 className={`${typography.display} text-[28px]`}>Choose a new password</h1>
      <div className="mt-6 space-y-4">
        <Field label="New password" type="password" value="••••••••••" palette={p} />
        <Field label="Confirm password" type="password" value="••••••••••" palette={p} />
        <PrimaryButton>Update password</PrimaryButton>
      </div>
      <div className="mt-6 rounded-[22px] p-4" style={{ background: p.softPink }}>
        <p className="text-[13px]" style={{ color: p.accentText }}>
          This reset link has expired. Request a new one.
        </p>
      </div>
    </ScreenFrame>
  )
}
