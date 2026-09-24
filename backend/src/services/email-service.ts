import type { Env } from '../env'

export interface EmailMessage {
  to: string
  subject: string
  html: string
  text: string
}

export interface EmailSender {
  send(message: EmailMessage): Promise<void>
}

class ResendEmailSender implements EmailSender {
  constructor(
    private readonly apiKey: string,
    private readonly from: string,
  ) {}

  async send(message: EmailMessage): Promise<void> {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: this.from,
        to: [message.to],
        subject: message.subject,
        html: message.html,
        text: message.text,
      }),
    })

    if (!response.ok) {
      const detail = await response.text()
      throw new Error(`Resend rejected the request (${response.status}): ${detail.slice(0, 300)}`)
    }
  }
}

/** Used when no email provider is configured (local dev and tests). */
class LoggingEmailSender implements EmailSender {
  async send(message: EmailMessage): Promise<void> {
    console.log('email_skipped', { to: message.to, subject: message.subject })
  }
}

export function emailSender(env: Env): EmailSender {
  if (env.RESEND_API_KEY && env.EMAIL_FROM) {
    return new ResendEmailSender(env.RESEND_API_KEY, env.EMAIL_FROM)
  }
  return new LoggingEmailSender()
}

export function passwordResetEmail(resetUrl: string, name: string): EmailMessage['html'] {
  return `<div style="font-family:system-ui,sans-serif;line-height:1.6">
  <h2 style="margin:0 0 12px">Reset your password</h2>
  <p>Hi ${escapeHtml(name)},</p>
  <p>Use the link below to choose a new password. It expires in 60 minutes and can only be used once.</p>
  <p><a href="${resetUrl}">Reset password</a></p>
  <p style="color:#6b7280">If you did not request this, you can ignore this email.</p>
</div>`
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}
