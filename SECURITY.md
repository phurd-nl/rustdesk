# NextSession — Security Notes

Covers the self-hosted API server (`apiserver/`, our fork of
`lejianwen/rustdesk-api`) and deployment hardening. The client/relay are RustDesk
upstream (tracked).

## API server audit (summary)

Focused audit of auth, crypto, OIDC, authorization, injection, secrets, deps.
**Verdict: fundamentally sound; adopted with the hardening below. No critical
findings.**

Done right: bcrypt passwords; `crypto/rand` for tokens; GORM parameterized
queries; OIDC with server-side state + nonce + PKCE; address-book queries scoped
`WHERE user_id = ?` with `userId` taken from the JWT (no IDOR); no baked-in
secrets (empty `jwt.key` = fail-closed); random one-time admin password.

### Fixed in code (branch `nextsession-hardening` on phurd-nl/rustdesk-api)
- Removed legacy static-salt MD5 password fallback (`utils/password.go`).
- Pinned JWT signing method to HMAC in `ParseToken` (`lib/jwt/jwt.go`).
- Initial admin password 8 → 20 chars (`cmd/apimain.go`).

### Deployment hardening (MUST do at VM bring-up)
1. **Set strong secrets — non-negotiable.** Shipped `conf/config.yaml` has empty
   `jwt.key` and DB password. Generate a ≥32-byte random `jwt.key`; an empty key
   disables login, a weak/shared key makes tokens forgeable. Inject `jwt.key`,
   DB creds, and the Entra client secret as **podman secrets**, not in the file.
2. **Bind private.** The API/admin listens on `0.0.0.0:21114`. Bind it to the
   internal interface / firewall it — consistent with the private-only network
   design (no public exposure).
3. **Disable LDAP.** We use Entra OIDC. Leave LDAP off so the
   `InsecureSkipVerify` path (when `TlsVerify` is false) is never reached.
4. **Run `govulncheck`** against `apiserver/` on the build host, and bump `gin`
   (1.9.0) to latest, before production.
5. **Secure the admin-password log.** The initial admin password is printed once
   to the log — capture it, then rotate the log / change the password.
6. **Force admin password change** on first console login.

### Microsoft Entra ID (OIDC) wiring
The client is provider-agnostic — it consumes whatever `/api/login-options`
advertises. Configure the API server's generic OIDC with:
- issuer: `https://login.microsoftonline.com/<tenant-id>/v2.0`
- client_id / client_secret: from the Entra app registration (secret → podman secret)
- redirect URI: the API server's `/api/oidc/callback`, registered in Entra
- scopes: `openid profile email`

### Residual / follow-up
- Second-pass review of the web-admin controllers (confirm every handler derives
  `userId` from `curUser`, never a request param) + add regression tests.
- Re-run this audit after each upstream merge into `phurd-nl/rustdesk-api`.

## Client / signing
- Custom-client signing private seed: `branding/secrets/` (gitignored). Back up
  to a vault / podman secret; loss ⇒ re-issue clients. See `BRANDING.md`.
- Rendezvous `RS_PUB_KEY` must match the hbbs `id_ed25519`.
