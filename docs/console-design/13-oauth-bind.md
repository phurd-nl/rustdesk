# OAuth Bind
`/oauth/bind/:code` · `src/views/oauth/bind.vue` · A signed-in user linking an external IdP identity to their existing account

## Purpose
Links (binds) a third-party identity-provider identity to an existing NextSession account, so the user can subsequently sign in via that provider. This is the confirm step after the IdP returns from a bind request.

## Layout & content
Centered card on a dark canvas (currently stock `#2d3a4b`/`#283342`), top→bottom:
- Title: "Linking account…".
- **Read-only info form**:
  - Provider (`Op`) — `oauthInfo.op` (the IdP being linked, e.g. google / github / oidc).
  - Third-party name (`ThirdName`) — `oauthInfo.third_name` (the external account's display name).
- **Bind** button (full width) — hidden once bound.
- **Close** button (full width).
- Helper line: close-window note.

## How it works
- Reads `code` from route params. If absent → redirects to `/` (stricter than oauth/login, which only comments the redirect out).
- `getInfo()` calls `info({ code })` to populate the provider + third-party name; on failure → redirect to `/`.
- **Bind** → `bindConfirm({ code })`. On success (`resStatus = 1`), branches on `res.data.device_type`:
  - `webadmin` → toast + redirect to `/` (the user is in the console, so route them home).
  - otherwise → toast + `window.close()` after 3s (popup/device flow).
- **Close** → `window.close()`.
- Permission: implicitly requires an authenticated account to bind to, plus a valid `code`.

## States
- **Loading**: card renders with empty Provider/Name until `info()` resolves.
- **Bound (webadmin)**: toast + redirect to `/`.
- **Bound (device flow)**: toast + auto-close after 3s.
- **Invalid / missing code**: redirects to `/` (no error shown). Consider a brief inline "This link is invalid or expired" before redirecting.
- **Error**: failed `info()`/`bindConfirm()` resolve to `false`; bind failure shows nothing today — add a user-facing message.

## Design direction
Same dark brand system as Login / OAuth Login; replace the stock `#2d3a4b` card.
- Canvas `#0b1622`, frosted card `#16212e`, NextSession wordmark above the card.
- **Bind is the primary, brand-orange `#f49e1b`** action (replace stock green); **Close** secondary translucent.
- Provider + third-party name as a labeled key/value block; muted labels, light values; emphasize the third-party account name so the user can confirm it's the right external identity.
- Reframe: make it explicit *which* console account the external identity is being attached to (the source shows the provider and external name but not the local account) — spec adds a "Linking to: <your account>" line.
- System UI font; comfortable single-decision density.

## Copy
- Title: "Link external account"
- Labels: "Provider", "External account"
- Add: "Linking to: <current account>"
- Buttons: "Link account" (primary), "Cancel"
- Bound toast: "Account linked"
- Bound (device) toast: "Account linked — this window will close shortly."
- Close note: "You can close this window once you're done."
- Invalid-link state: "This link is invalid or has expired."
