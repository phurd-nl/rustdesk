# API Tokens
Route `/userToken` · `src/views/user/token.vue` · Audience: System (admin-only)

## Purpose
Lists every active session/API token across all users so an admin can review and revoke them (force sign-out).

## Layout & content
Top→bottom:

1. **Toolbar card** — `User` filter (select, clearable, populated from all users) + `Filter` button + `BatchDelete` button.
2. **Tokens table** — row-select checkbox column, plus:
   - **id** (`id`)
   - **Owner** — username tag resolved from `user_id`
   - **Token** — masked: first 4 + `****` + last 4 chars (`maskToken`)
   - **CreatedAt** (`created_at`)
   - **ExpireTime** (`expired_at`) — tag; localized date or `-`; tag is grey `info` when expired, green `success` when still valid
   - **Actions** — `Logout` (danger, revokes the token)
3. **Pagination** — page sizes 10/20/50/100.

## How it works
- `getList` loads on mount/activate and on page change; `handlerQuery` resets to page 1.
- User filter narrows by `user_id`.
- `expired(row)` compares `expired_at * 1000` against now.
- **Logout** (`del`) revokes a single token.
- **BatchDelete** revokes all checked tokens (`batchDelete` over selected ids); no-op if selection empty.
- Owner usernames resolved client-side from the `allUsers` list.

## States
- **Empty:** stock "No Data" — reframe.
- **Loading:** table spinner.
- **Error:** swallowed; no message.
- **No-permission:** admin-only route.

## Design direction
- Light canvas; white cards, 14px radius, soft shadow; system-UI font.
- Keep tokens **always masked** — never render a full token; the mask is correct, preserve it. No copy-full-token affordance.
- ExpireTime as a **dot+label pill**: valid = success `#27a35a`, expired = muted grey `#646e78` (not alarming).
- "Logout"/revoke is destructive → danger `#f03a3a` but secondary weight; confirm on single and batch.
- Owner as a quiet tag in foreground `#1b1f24`; comfortable table density (these rows are scanned, not data-dense).
- Empty state: bordered panel "No active tokens".

## Copy
- Page title: "API tokens" (replace "UserToken")
- Filter label: "User"
- Buttons: "Filter", "Revoke selected" (replace "BatchDelete")
- Columns: "ID", "Owner", "Token", "Created", "Expires", "Actions"
- Action: "Revoke" (replace "Logout")
- Expires cell when none: "Never" (replace "-" where applicable)
- Empty state: "No active tokens"
