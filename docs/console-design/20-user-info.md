# User Info
Route `/my/info` · `src/views/my/info.vue` · Audience: My (the signed-in tech's own account)

## Purpose
Shows the technician's own account identity and lets them change their password and link/unlink their identity provider (Microsoft Entra ID).

## Layout & content
Top→bottom:

1. **Account card** — a centered form (600px) with read-only rows:
   - Username (text)
   - Email (text)
   - Password row → a "Change password" button (no value shown)
   - Identity provider table (the "OIDC" row). Columns:
     - **Provider** (`op`) — the IdP key (e.g. `entra`)
     - **Status** — badge: linked (success) / not linked (danger)
     - **Actions** — "Unlink" if linked, "Link" if not
2. **Welcome / hello card** — a second card rendering server-configured Markdown (`appStore.setting.hello`) as HTML. Hidden in practice when empty.
3. **Change-password dialog** (`changePwdDialog.vue`) — modal form: Old password, New password, Confirm password. All required; new ≠ old; confirm must match. On success the user is logged out and the page reloads. Note: for OIDC-only accounts with no password, the helper text says "enter any 4–20 letters" for the old password.

## How it works
- On load, `myOauth()` fills the provider table (`oidcData`).
- **Link** → `bind({op})` returns a URL; opens it in a new window to start the OAuth flow.
- **Unlink** → confirm dialog, then `unbind({op})`, then reloads the provider table.
- Username/Email come from the user store (no edit here).

## States
- **Empty provider table:** stock UI shows Element Plus "No Data". This is the screenshot's weak spot — reframe (see below).
- **Loading:** provider table fetch is silent (no spinner).
- **Error:** API calls swallow errors (`.catch(_ => false)`); no user-facing message today — add one.

## Design direction
- Light canvas `#f6f8fa`; white card, 14px radius, soft shadow. Use system-UI font.
- Render account identity as a clean **profile header**, not an Element form: avatar/initials block, name in foreground `#1b1f24`, email in muted `#646e78`. Drop the colon label-suffix.
- "Change password" is a low-frequency, non-destructive action — make it a **secondary/ghost button**, not the stock red `danger` button.
- Status should be a **colored dot + label** badge: linked = success `#27a35a`, not linked = neutral grey (not alarming red).
- **Empty IdP state (key reframe):** instead of "No Data", show a bordered empty panel with a short line — "Sign in faster with your Microsoft work account" — and a primary blue `#0559c9` **"Link Microsoft Entra ID"** button. Once linked, collapse to a single row: "Microsoft Entra ID · Linked" with an "Unlink" ghost button.
- Primary action buttons in primary blue; hover wash `#e6f0ff`.

## Copy
- Card title: "Account" (replace "Userinfo")
- "Username", "Email"
- Button: "Change password"
- Section: "Sign-in methods" (replace bare "OIDC")
- Column: "Provider" (replace "IdP" raw key); render `entra` as "Microsoft Entra ID"
- Column: "Status" → badges "Linked" / "Not linked" (replace "HasBind"/"NoBind")
- Actions: "Link" / "Unlink" (replace "ToBind"/"UnBind")
- Empty state: heading "No sign-in method linked", body "Link your Microsoft Entra ID to sign in with your work account.", button "Link Microsoft Entra ID"
- Change-password dialog: "Current password", "New password", "Confirm new password", "Save", "Cancel"
