import js from '@eslint/js'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  // `.wrangler` holds bundler output written by `wrangler dev`, not source.
  { ignores: ['node_modules', 'dist', '.wrangler', 'worker-configuration.d.ts'] },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
)
