# Login
`/login` · `src/views/login/login.vue` · Unauthenticated admins / operators

## Purpose
Single entry point for the admin console. Authenticates by username + password and/or hands off to a configured SSO/OIDC identity provider.

## Layout & content
Full-screen centered column on the dark brand canvas, top→bottom:
- **NextSession wordmark** (centered image, ~300px wide).
- **Frosted card** containing:
  - Title: "Login".
  - **Password form** (hidden when SSO-only):
    - Username — text input.
    - Password — password input (show/hide toggle, Enter submits).
    - Captcha — text input with an inline clickable captcha image; shown only when the server demands one.
    - Buttons: **Login** (primary), **Register** (secondary, only when registration is enabled).
  - **Divider** "or sign in with" — shown only when providers exist AND password login is enabled.
  - **Provider buttons** — one per OIDC option, each with the provider icon + label (Google / GitHub / generic OIDC).
  - **SSO-empty notice** — shown only in SSO-only mode when no provider is configured.
- **Footer**: "NextSession · secured by Nextlink".

## How it works
- On mount, if an auth `code` is present (post-OIDC return), it calls `userStore.query(code)`, clears the code, and redirects to `redirect` query param or `/`.
- Otherwise it calls `/api/login-options` (`loginOptions()`), which returns:
  - `ops[]` — provider names → rendered as buttons.
  - `auto_oidc` — when true, immediately invokes the **first** provider (no click needed).
  - `disable_pwd` — when true, hides the password form (SSO-only mode).
  - `register` — toggles the Register button.
  - `need_captcha` — pre-loads a captcha on render.
- **Login** posts the form via `userStore.login`. On success → toast + redirect. Response code `110` means captcha required → `loadCaptcha()` re-renders the captcha field.
- **Provider button** → `userStore.oidc(provider, platform, browser)`. Platform/browser are sniffed from `navigator` and sent along.
- **Register** routes to `/register`.
- No permission gate — this is the pre-auth page.

## States
- **Loading**: brief window before `login-options` resolves; card renders with form, providers/captcha appear after.
- **SSO-only (`disable_pwd`)**: password form hidden; single provider auto-redirects (`auto_oidc`) and its button is the orange primary CTA labeled "Use single sign-on"; multiple providers each named.
- **SSO-only, no provider**: notice "No single sign-on provider is configured." — a dead-end the operator must fix server-side.
- **Captcha required**: triggered on first load (`need_captcha`) or after a failed login (code 110).
- **Error**: failed credentials surface as a toast; the page itself does not show inline field errors.

## Design direction
This is the deliberate **dark brand moment** — do not apply the app's light theme here.
- Canvas `#0b1622` with the subtle dual radial-gradient glow (orange top-right, blue bottom-left) already in source.
- Frosted card `#16212e` (≈0.92 alpha), 14px radius, soft drop shadow.
- **Primary action is brand-orange `#f49e1b`** (overrides the app's blue `#0559c9` on this screen only); dark text `#1b1206` on the orange button for contrast.
- Secondary buttons and provider buttons: translucent white fill, hairline border, light-gray text; hover tints toward orange.
- Inputs: near-transparent fill, hairline inset border, orange focus ring.
- System UI font stack. Comfortable density — generous 32px card padding, 44–48px control height; this is a focus screen, not a dense table.

## Copy
- Title: "Login"
- Fields: "Username", "Password", "Captcha"
- Buttons: "Login", "Register"
- Divider: "or sign in with"
- SSO-only single-provider button: "Use single sign-on"
- SSO-empty notice: "No single sign-on provider is configured."
- Success toast: "Signed in"
- Footer: "NextSession · secured by Nextlink"
