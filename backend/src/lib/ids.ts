export function newId(): string {
  return crypto.randomUUID()
}

export function nowIso(): string {
  return new Date().toISOString()
}

/** Normalises a display name for duplicate detection. */
export function normaliseName(name: string): string {
  return name.trim().replace(/\s+/g, ' ').toLowerCase()
}

export function normaliseEmail(email: string): string {
  return email.trim().toLowerCase()
}
