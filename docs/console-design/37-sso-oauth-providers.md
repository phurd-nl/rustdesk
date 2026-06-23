# SSO / Identity Providers
Route `/oauth` · `src/views/oauth/index.vue` · Audience: System (admin-only)

## Purpose
Register and manage the identity providers technicians sign in through. The primary use is adding a **Microsoft Entra ID (OIDC)** provider so staff authenticate with their work account instead of a local password.

## Layout & content
Top→bottom:

1. **Toolbar card** — `Filter` button + `Add` button.
2. **Providers table** — columns:
   - **ID** (`id`)
   - **IdP** (`op`) — the provider key (e.g. `entra`)
   - **Type** (`oauth_type`) — `oidc` / `github` / `google` / `linuxdo`
   - **AutoRegister** (`auto_register`) — boolean
   - **PkceEnable** (`pkce_enable`) — boolean
   - **PkceMethod** (`pkce_method`) — `S256` / `plain`
   - **CreatedAt** / **UpdatedAt**
   - **Actions** — `Edit`, `Delete`
3. **Pagination** — page sizes 10/20/50/100.
4. **Add/Edit dialog** (800px) — the provider form. Fields:
   - **Type** (`oauth_type`) — radio group: GitHub, Google, LinuxDo, **OIDC**. *Disabled (locked) when editing an existing provider* (`:disabled="!!formData.id"`). Required.
   - **IdP** (`op`) — text. *Shown only when Type = oidc.* Required for OIDC. The provider key; placeholder "Your IdP Name". For Entra, enter `entra`.
   - **Issuer** (`issuer`) — text. *Shown only when Type = oidc.* Required. Placeholder warns to omit the `/.well-known/openid-configuration` suffix. For Entra: `https://login.microsoftonline.com/<TENANT_ID>/v2.0`.
   - **Scopes** (`scopes`) — text. *Shown for oidc.* Optional; default `openid,profile,email`.
   - **ClientId** (`client_id`) — text. Required.
   - **ClientSecret** (`client_secret`) — password/secret. Required. **On create:** plain `text` input with `show-password` reveal toggle. **On edit:** rendered as `type="password"` (masked, no reveal). See security note below.
   - **RedirectUrl** (`redirect_url`) — *read-only display, not an input.* Shows the callback URL `<api_server>/api/oidc/callback` with a copy-to-clipboard icon. This is the value the admin pastes into Entra's app registration.
   - **PkceEnable** (`pkce_enable`) — switch (true/false).
   - **PkceMethod** (`pkce_method`) — select, *shown only when PkceEnable is on*: `S256 (Recommended)` / `Plain`. Validated to be one of `S256`/`plain`.
   - **AutoRegister** (`auto_register`) — switch, with helper note: a new local account is created on first successful SSO login.
   - Footer: `Cancel`, `Submit`.

## How it works
- On mount/activate, `list(listQuery)` loads the providers table.
- **Add** opens the dialog with empty defaults (`pkce_method` pre-set to `S256`).
- **Edit** loads the row into the form. Type is locked; `client_secret` is bound from the row but masked.
- **RedirectUrl** is computed: `${app.setting.rustdeskConfig.api_server || window.location.origin}/api/oidc/callback`. Clicking it copies via `handleClipboard`.
- **Submit** validates rules (`client_id`, `client_secret`, `oauth_type`, `issuer` required; `pkce_method` constrained), then calls `create` or `update`. Success toast, dialog closes, list refreshes.
- **Delete** → confirm dialog → `remove({id})` → refresh.
- **Secret handling (important):** the stored `client_secret` is bound into the edit form's model from the list response. The design must treat the secret as write-only at the UI layer — never echo the stored value in the masked field, never show it in the table, and never log it. Spec it so the edit field shows a "secret is set" placeholder and only sends a new value if the admin types one; an empty secret field on edit means "keep existing".

## States
- **Empty:** stock shows Element Plus "No Data" — reframe (below).
- **Loading:** table spinner (`v-loading`).
- **Error:** API errors swallowed (`.catch(_ => false)`); no user-facing message — add one.
- **No-permission:** route is admin-only; non-admins never reach it.

## Design direction
- Light canvas `#f6f8fa`; white cards, 14px radius, soft shadow; system-UI font; radius 8px on controls.
- This is the **flagship admin page** — make the empty state strong: a bordered panel reading "No identity providers" with subtext "Let your team sign in with their Microsoft work account." and a primary blue `#0559c9` **"Add Microsoft Entra ID"** button that opens the dialog pre-filled for OIDC/Entra (Type = OIDC, IdP = `entra`, Issuer template, Scopes default, PKCE on/S256).
- Render each provider as a **row/card** showing: type icon + friendly name ("Microsoft Entra ID" for `entra`/oidc), a status pill (Enabled = success `#27a35a` dot+label; Disabled = neutral grey), and the **callback URL with a copy button** inline so the admin can grab it without opening Edit.
- In the Add/Edit dialog, place the **read-only Redirect/Callback URL in a copy-field block** with helper text "Paste this into your Entra app registration's Redirect URI."
- Booleans in the table → pills/switches, not raw `true`/`false`.
- Treat `client_secret` visually as sensitive: masked field, lock/key affordance, "••• set" placeholder once saved; never a plaintext column.
- Primary actions blue; hover wash `#e6f0ff`. `Delete` stays danger `#f03a3a` but secondary in weight.

## Copy
- Page title: "Identity providers" (replace "OauthManage")
- Toolbar: "Filter", "Add provider"
- Columns: "ID", "Provider", "Type", "Auto-register", "PKCE", "Method", "Created", "Updated", "Actions"
- Render `oidc`+`entra` as "Microsoft Entra ID"; show booleans as "On"/"Off"
- Dialog title: "Add provider" / "Edit provider"
- Field labels: "Type", "Provider key", "Issuer URL", "Scopes", "Client ID", "Client secret", "Redirect / callback URL", "PKCE", "PKCE method", "Auto-register"
- Issuer help: "Your IdP issuer URL, without `/.well-known/openid-configuration`. For Entra: `https://login.microsoftonline.com/<TENANT_ID>/v2.0`"
- Scopes help: "Optional. Default: `openid,profile,email`"
- Client secret (edit) placeholder: "••• set — leave blank to keep current"
- Redirect help: "Paste this into your Entra app registration's Redirect URI"
- Auto-register note: "Create a console account automatically on first successful sign-in."
- PKCE method options: "S256 (recommended)", "Plain"
- Buttons: "Cancel", "Save"
- Empty state: heading "No identity providers", body "Let your team sign in with their Microsoft work account.", button "Add Microsoft Entra ID"
