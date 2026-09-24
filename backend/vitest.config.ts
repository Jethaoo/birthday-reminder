import { defineWorkersConfig, readD1Migrations } from '@cloudflare/vitest-pool-workers/config'
import path from 'node:path'

export default defineWorkersConfig(async () => {
  // Migrations are read once and injected so every test run starts from the
  // real schema rather than a hand-written approximation of it.
  const migrations = await readD1Migrations(path.join(__dirname, 'migrations'))

  return {
    test: {
      setupFiles: ['./tests/setup.ts'],
      poolOptions: {
        workers: {
          wrangler: { configPath: './wrangler.jsonc' },
          miniflare: {
            bindings: {
              TEST_MIGRATIONS: migrations,
              JWT_SECRET: 'test-secret-not-used-in-production',
              ENVIRONMENT: 'test',
              APP_BASE_URL: 'http://localhost:8443',
            },
          },
        },
      },
    },
  }
})
