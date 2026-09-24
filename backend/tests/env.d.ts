/* eslint-disable @typescript-eslint/no-empty-object-type */
import type { Env } from '../src/env'

declare module 'cloudflare:test' {
  // Makes the Worker's bindings visible to `env` inside tests.
  interface ProvidedEnv extends Env {}
}
