/** Design tokens shared by every screen in the design surface. */

export type Palette = {
  background: string
  surface: string
  surfaceVariant: string
  primary: string
  onPrimary: string
  accent: string
  accentText: string
  textPrimary: string
  textSecondary: string
  border: string
  error: string
  softPink: string
  softGreen: string
  heroCard: string
  heroCardText: string
  avatarTints: string[]
}

export const light: Palette = {
  background: '#F8F8F4',
  surface: '#FFFFFF',
  surfaceVariant: '#ECEEE9',
  primary: '#293D32',
  onPrimary: '#FFFFFF',
  accent: '#FB8269',
  accentText: '#D75A45',
  textPrimary: '#243029',
  textSecondary: '#7C857F',
  border: '#E5E5DC',
  error: '#B94D38',
  softPink: '#FDE5DE',
  softGreen: '#E6F0DC',
  heroCard: '#293D32',
  heroCardText: '#FFFFFF',
  avatarTints: ['#FFDDD2', '#D8E6FF', '#DFF4DC', '#F1DCFF'],
}

export const dark: Palette = {
  background: '#0F1512',
  surface: '#18201B',
  surfaceVariant: '#222C26',
  primary: '#4E6B57',
  onPrimary: '#FFFFFF',
  accent: '#FF9C86',
  accentText: '#FF9C86',
  textPrimary: '#EDF1EC',
  textSecondary: '#9BA69F',
  border: '#2B352F',
  error: '#FF8A75',
  softPink: '#3A2622',
  softGreen: '#1E2A22',
  heroCard: '#1E2A22',
  heroCardText: '#EDF1EC',
  avatarTints: ['#4A2F29', '#25334A', '#26382A', '#35263F'],
}

export const radius = {
  card: '22px',
  sheet: '28px',
  field: '14px',
  pill: '999px',
}

export const typography = {
  display: "font-[Fraunces] text-[30px] font-bold tracking-[-1.2px]",
  headline: "font-[Fraunces] text-[22px] font-bold tracking-[-0.6px]",
  title: 'text-[18px] font-bold tracking-[-0.4px]',
  body: 'text-[14px]',
  caption: 'text-[12px]',
  label: 'text-[11px] font-bold uppercase tracking-[0.1em]',
}

export const relationshipFilters = ['All', 'Today', 'This week', 'This month', 'Family', 'Friend', 'Colleague', 'Other']

export const reminderPeriods = [0, 1, 3, 7, 14, 30]

export const reminderLabel = (days: number) =>
  days === 0 ? 'On birthday' : days === 1 ? '1 day before' : `${days} days before`

export const countdownLabel = (days: number) =>
  days === 0 ? 'Today' : days === 1 ? 'Tomorrow' : `${days} days`
