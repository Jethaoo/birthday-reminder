import { applyD1Migrations, env } from 'cloudflare:test'
import type { D1Migration } from '@cloudflare/vitest-pool-workers/config'

// Every test starts from the real migration set, including foreign keys.
const migrations = (env.TEST_MIGRATIONS ?? []) as D1Migration[]
await applyD1Migrations(env.DB, migrations)
