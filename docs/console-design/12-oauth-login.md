# OAuth Login Confirmation
`/oauth/login/:code` · `src/views/oauth/login.vue` · A user completing IdP sign-in (typically in a popup/browser tab opened by a device or the console)

## Purpose
Post-IdP confirmation handoff: after the identity provider returns, this screen shows which device/session is requesting access and lets the user approve it. It is the human-in-the-loop confirm step of the OAuth flow, not a credential form.

## Layout & content
Centered card on a dark canvas (currently stock `#2d3a4b`/`#283342`), top→bottom:
- Title: "Signing in…".
- **Read-only info form**:
  - Device — `oauthInfo.device_name`.
  - ID — `oauthInfo.id` (the requesting device/session ID).
- **Confirm** button (full width) — hidden once confirmed.
- **Close** button (full width).
- Helper line: close-window note.

## How it works
- Reads `code` from the route params (`route.params.code`). If absent, source has the redirect commented out, so it currently stays on the page.
- `getInfo()` calls `info({ code })` (`@/api/oauth`) on load and populates the device name + ID.
- **Confirm** → `confirm({ code })`. On success: sets `resStatus = 1` (hides the Confirm button), shows a success toast, and auto-runs `out()` after 3 seconds.
- **Close** → `window.close()` (this view is meant to live in a popup/standalone tab).
- No permission gate beyond possession of a valid `code`.

## States
- **Loading**: card renders with empty Device/ID until `info()` resolves.
- **Confirmed**: Confirm button removed; success toast; window auto-closes after 3s.
- **Invalid / missing code**: `info()` fails silently (redirect is commented out) — the card sits with blank fields. Spec should add an explicit "This sign-in link is invalid or expired." state.
- **Error**: failed `info()`/`confirm()` resolve to `false`; no user-facing message today — add one.

## Design direction
Pull this into the same dark brand system as Login instead of the stock `#2d3a4b` card.
- Canvas `#0b1622`, frosted card `#16212e`, 8–14px radius, same shadow.
- Show the NextSession wordmark above the card so a popup still reads as branded.
- **Confirm is the primary, brand-orange `#f49e1b`** action (replace the stock green `type="success"`); **Close** is the secondary translucent button.
- Present Device + ID as a labeled key/value block, muted `#646e78` labels, foreground `#1b1f24`-equivalent light value text on the dark card; the requesting ID is the emphasized line.
- System UI font; comfortable density — this is a one-decision screen.

## Copy
- Title: "Confirm sign-in"
- Labels: "Device", "Session ID"
- Buttons: "Approve sign-in" (primary), "Cancel"
- Confirmed toast: "Approved — this window will close shortly."
- Close note: "You can close this window once you're done."
- Invalid-link state: "This sign-in link is invalid or has expired."
