# Birthday Reminder design surface

React 19 + Vite 8 + Tailwind CSS v4 project used as the runnable visual reference for the shipping
Flutter Android app in `app/`. This project is not shipped and has no backend connection or account
state.

## Development

```bash
pnpm install
pnpm dev
```

The development server listens on <http://localhost:8443> by default. Set `PORT` to use another
port. The Figma Make preview can also run the same server; neither mode requires a Worker.

## Checks

```bash
pnpm exec tsc --noEmit
pnpm build
```

CI runs both commands. Update this surface in the same change whenever a shipping screen's visual
language changes. For product and workflow guidance, also check
[`src/assets/reference.md`](src/assets/reference.md).

## Project structure

- `src/main.tsx` mounts React into `#root`.
- `src/App.tsx` mounts the design surface.
- `src/DesignSurface.tsx` indexes the screens, components, states and flows.
- `src/screens/` contains the auth, main-app, settings and state variants.
- `src/components.tsx` contains shared visual primitives.
- `src/theme.ts` contains light/dark tokens, typography and labels.
- `src/data.ts` contains deterministic display fixtures.
- `src/assets/reference.md` contains the V1 product/design reference.
- `src/index.css` imports Tailwind CSS v4 and the web fonts.
- `vite.config.ts` configures React, Tailwind, Figma Make integration and the `@` alias.
- `.mise.toml` pins Node 22 and pnpm for environments that use mise.

## Dependencies

- Runtime: React 19 and React DOM 19.
- Styling: Tailwind CSS v4 through `@tailwindcss/vite`.
- Build tooling: Vite 8, TypeScript 5.7 and `@vitejs/plugin-react`.
- Formatting: oxfmt.

## Styling

The project uses Tailwind CSS v4 through `@tailwindcss/vite`; there is no Tailwind config or PostCSS
config file. Prefer utility classes in JSX and keep global CSS, `@font-face` rules and font-family
defaults in `src/index.css`. Keep CSS `@import` statements first.

## V1 scope

The surface covers the four-tab Android app, auth and password reset, birthday management, multiple
reminders, contact import, settings, notifications and offline/error states. AI birthday wishes and
Google sign-in are not part of V1.
