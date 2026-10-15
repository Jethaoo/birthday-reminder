import { Hono } from 'hono'
import type { AppEnv } from '../env'

/**
 * The password-reset email links here. The page reads the token from the URL,
 * collects the new password and calls `POST /api/auth/reset-password`, so the
 * flow works from any mail client without the app being installed.
 *
 * The token is in the URL, so the page is never cached and never sends a
 * referrer. The script is served from its own path to keep a strict CSP.
 */
const resetPage = new Hono<AppEnv>()

const SECURITY_HEADERS: Record<string, string> = {
  'Cache-Control': 'no-store',
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Content-Security-Policy':
    "default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; connect-src 'self'; " +
    "form-action 'none'; base-uri 'none'; frame-ancestors 'none'",
}

const PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Reset your password · Birthday Reminder</title>
<style>
  :root { color-scheme: light dark; --bg: #faf7f2; --fg: #2b2118; --muted: #6b5d50; --accent: #c2410c; --card: #fff; --line: #e7ded3; }
  @media (prefers-color-scheme: dark) { :root { --bg: #17120e; --fg: #f5ede4; --muted: #b5a698; --accent: #fb923c; --card: #221b15; --line: #3a2f26; } }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 16px; background: var(--bg); color: var(--fg); font: 16px/1.5 system-ui, sans-serif; }
  main { width: 100%; max-width: 380px; background: var(--card); border: 1px solid var(--line); border-radius: 16px; padding: 24px; }
  h1 { font-size: 1.35rem; margin: 0 0 4px; }
  p { margin: 0 0 16px; color: var(--muted); }
  label { display: block; font-weight: 600; margin: 12px 0 4px; }
  input { width: 100%; padding: 10px 12px; border-radius: 10px; border: 1px solid var(--line); background: transparent; color: inherit; font: inherit; }
  button { margin-top: 20px; width: 100%; padding: 12px; border: 0; border-radius: 10px; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  button:disabled { opacity: .6; cursor: default; }
  #status { margin: 16px 0 0; min-height: 1.5em; }
  #status.error { color: #dc2626; }
  [hidden] { display: none !important; }
</style>
</head>
<body>
<main>
  <h1>Reset your password</h1>
  <p id="intro">Choose a new password for your Birthday Reminder account.</p>
  <form id="form" novalidate>
    <label for="password">New password</label>
    <input id="password" type="password" autocomplete="new-password" minlength="8" required>
    <label for="confirm">Confirm new password</label>
    <input id="confirm" type="password" autocomplete="new-password" minlength="8" required>
    <button id="submit" type="submit">Reset password</button>
  </form>
  <p id="status" role="status" aria-live="polite"></p>
</main>
<script src="/reset-password.js"></script>
</body>
</html>`

const SCRIPT = `(function () {
  var token = new URLSearchParams(location.search).get('token') || '';
  // Drop the token from the address bar and history once it has been read.
  history.replaceState(null, '', location.pathname);
  var form = document.getElementById('form');
  var status = document.getElementById('status');
  var submit = document.getElementById('submit');
  function show(message, isError) {
    status.textContent = message;
    status.className = isError ? 'error' : '';
  }
  if (!token) {
    form.hidden = true;
    show('This reset link is incomplete. Request a new one from the app.', true);
    return;
  }
  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var password = document.getElementById('password').value;
    var confirmPassword = document.getElementById('confirm').value;
    if (password !== confirmPassword) { show('The passwords do not match.', true); return; }
    submit.disabled = true;
    show('Saving…', false);
    fetch('/api/auth/reset-password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: token, password: password, confirmPassword: confirmPassword })
    }).then(function (response) {
      if (response.ok) {
        form.hidden = true;
        document.getElementById('intro').hidden = true;
        show('Your password has been reset. Open the app and sign in with your new password.', false);
        return;
      }
      return response.json().catch(function () { return null; }).then(function (body) {
        var message = body && body.error && body.error.message;
        show(message || 'The password could not be reset. Try again.', true);
        submit.disabled = false;
      });
    }).catch(function () {
      show('No connection. Check your internet and try again.', true);
      submit.disabled = false;
    });
  });
})();`

resetPage.get('/reset-password', (c) => c.html(PAGE, 200, SECURITY_HEADERS))

resetPage.get('/reset-password.js', (c) =>
  c.body(SCRIPT, 200, {
    ...SECURITY_HEADERS,
    'Cache-Control': 'public, max-age=3600',
    'Content-Type': 'text/javascript; charset=utf-8',
  }),
)

export default resetPage
