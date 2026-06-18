# NextSession SSO — Microsoft Entra ID (OIDC)

Pre-staged so it's copy-paste on the VM. **No code needed** — the client speaks
OIDC and our API-server fork has a generic `oidc` provider. This is pure config.

Fixed values (already set by `server/deploy-api.sh`):
- **Redirect URI:** `https://nextsession.nxlink.com/api/oidc/callback`
  (the server derives this from `RUSTDESK_API_RUSTDESK_API_SERVER`)
- **Issuer:** `https://login.microsoftonline.com/<TENANT_ID>/v2.0`
- **Scopes:** `openid profile email`

---

## Part A — Entra app registration (Azure portal → Entra ID → App registrations)

1. **New registration**
   - Name: `NextSession`
   - Supported account types: **Single tenant** (this org only)
   - Redirect URI: platform **Web** → `https://nextsession.nxlink.com/api/oidc/callback`
2. Copy the **Application (client) ID** and **Directory (tenant) ID**.
3. **Certificates & secrets** → **New client secret** → copy the **Value**
   (not the Secret ID). This is the `client_secret`.
4. **Token configuration** → **Add optional claim** → token type **ID** →
   add **`email`** (and optionally `upn`). *Why: Entra returns `name` and
   `preferred_username` by default — which the server maps to display name and
   username — but `email` is only emitted when this optional claim (or the
   `email` scope with a mail-enabled account) is present. See the caveat below.*
5. **API permissions** → ensure Microsoft Graph delegated `openid`, `profile`,
   `email` (added by default for OIDC; grant admin consent if your tenant requires it).

You now have: `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`.

---

## Part B — NextSession console (recommended path)

Open `https://nextsession.nxlink.com/_admin/` (admin + the password printed by
`deploy-api.sh`) → **OAuth** → add a provider:

| Field | Value |
|---|---|
| Type (`oauth_type`) | `oidc` |
| Name (`op`) | `entra` |
| Issuer | `https://login.microsoftonline.com/<TENANT_ID>/v2.0` |
| Client ID | `<CLIENT_ID>` |
| Client Secret | `<CLIENT_SECRET>` |
| Scopes | `openid,profile,email` |
| PKCE | enabled, method `S256` |
| Auto-register | **on** to auto-create a tech account on first SSO login; **off** to require an admin to pre-create users |

Save. The client's login screen will now show the SSO option (advertised via
`/api/login-options` as `oidc/entra`).

---

## Part C — Optional: SQL seed (automation instead of the console)

OIDC providers live in the DB `oauth` table — there is no config/env for them, so
either use the console (Part B) or seed the row. The `client_secret` is stored in
the DB (inherent to this server — protect the DB / volume).

> Verify table/column names against the running schema before applying — GORM
> generates them (table likely `oauths`, snake_case columns).

```sql
-- sqlite / postgres
INSERT INTO oauths (op, oauth_type, client_id, client_secret, issuer, scopes,
                    pkce_enable, pkce_method, auto_register, created_at, updated_at)
VALUES ('entra', 'oidc', '<CLIENT_ID>', '<CLIENT_SECRET>',
        'https://login.microsoftonline.com/<TENANT_ID>/v2.0',
        'openid,profile,email', 1, 'S256', 1, datetime('now'), datetime('now'));
```

---

## Part D — Verify & the one caveat

1. In the NextSession client, choose **Log in → SSO** → redirected to Microsoft →
   consent → returned and logged in. A user is provisioned (if auto-register on).
2. **Caveat — empty email:** if the provisioned user has no email, the `email`
   optional claim (Part A step 4) wasn't applied. Username/display still work
   (`preferred_username`/`name` are default), so login succeeds — but add the
   claim if you key anything off email. If the server rejects login when email is
   required, that's a small mapping tweak on our fork (`OidcUser.ToOauthUser`),
   not a redesign.
3. Optional: set `app.disable-pwd-login: true` once SSO works, to force SSO-only.
