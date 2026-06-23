# Register
`/register` · `src/views/register/index.vue` · Prospective admins / operators (self-service)

## Purpose
Self-service account creation when the server permits open registration. Creates the account and signs the user straight in.

## Layout & content
Same dark brand layout as Login: centered wordmark over a frosted card, top→bottom:
- **NextSession wordmark**.
- **Frosted card**:
  - Title: "Register".
  - **Form** (`label-position="top"`, validated):
    - Username — text, **required**.
    - Email — text, **optional** (validation rule is commented out in source; no format check).
    - Password — password input, show/hide, **required**.
    - Confirm password — password input, show/hide, **required**, must equal Password (Enter submits).
    - Buttons: **Submit** (primary orange), **Back to login** (secondary).
- **Footer**: "NextSession · secured by Nextlink".

## How it works
- Form runs Element Plus validation on submit (`f.value.validate()`); aborts on failure.
- Calls `register(form)` (`@/api/user`). On success:
  - `userStore.saveUserData(res.data)` — registration returns a session, so the user is logged in immediately.
  - `useAppStore().loadConfig()` reloads app config.
  - Toast, then redirect to `/`.
- **Back to login** routes to `/login`.
- No permission gate. Note: this page does **not** itself check whether registration is enabled — that gate lives on Login (the `register` flag from `login-options` controls whether the Register button appears). Reaching `/register` directly when `APP_REGISTER=false` will surface a server-side error on submit rather than being blocked client-side.

## States
- **Validation error**: required-field and password-mismatch messages render inline under each field.
- **Registration disabled (server)**: `APP_REGISTER=false` — the Register entry point is hidden on Login; a direct visit to `/register` fails at submit. Spec a friendly inline notice ("Registration is currently disabled. Contact your administrator.") rather than a raw API error toast.
- **Error**: failed submit surfaces as a toast.

## Design direction
Identical dark brand treatment to Login (shared tokens, shared card). Keep the two screens visually interchangeable.
- Orange `#f49e1b` primary on **Submit**; secondary translucent **Back to login**.
- Same input styling: transparent fill, hairline inset border, orange focus ring, light text.
- System UI font; 32px card padding; 44px controls.
- Reframe from stock: when registration is disabled, prefer a calm explanatory card over an error toast.

## Copy
- Title: "Register"
- Fields: "Username", "Email", "Password", "Confirm password"
- Buttons: "Create account" (replaces stock "Submit"), "Back to login"
- Validation: "Username is required", "Password is required", "Confirm password is required", "Passwords do not match"
- Registration-disabled notice: "Registration is currently disabled. Contact your administrator."
- Success toast: "Account created"
- Footer: "NextSession · secured by Nextlink"
