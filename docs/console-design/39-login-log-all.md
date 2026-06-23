# Login Log (All Users)
Route `/loginLog` · `src/views/login/log.vue` · Audience: System (admin-only)

## Purpose
Org-wide record of client/console sign-ins, so an admin can see who logged in from where and on what device, and export the log.

## Layout & content
Top→bottom:

1. **Toolbar card** — `User` filter (select, clearable) + `Filter` + `BatchDelete` + `Export`.
2. **Login table** — row-select checkbox, plus:
   - **ID** (`id`)
   - **Owner** — username tag from `user_id`
   - **client** (`client`)
   - **Peer** — `device_id` (falls back to peer id)
   - **uuid** (`uuid`)
   - **ip** (`ip`)
   - **type** (`type`)
   - **Platform/UA** (`platform`) — overflow-tooltip
   - **CreatedAt** (`created_at`)
   - **Actions** — `Delete` (danger)
3. **Pagination** — 10/20/50/100.

## How it works
- `useRepositories('admin')` — the `'admin'` arg scopes this to the org-wide log (vs. a per-user view).
- `getList` on mount/activate and page change; `handlerQuery` resets to page 1.
- User filter narrows by `user_id`.
- **Delete** removes a single row; **BatchDelete** removes checked rows (no-op if empty).
- **Export** (`toExport`) downloads the log (CSV via `jsonToCsv`/`downBlob`).

## States
- **Empty:** stock "No Data" — reframe.
- **Loading:** table spinner.
- **Error:** swallowed.
- **No-permission:** admin-only.

## Design direction
- Light canvas; white cards, 14px radius; system-UI font.
- This is **dense audit data** — use a tighter table density (compact row height, monospace for `ip`/`uuid`).
- Truncate long Platform/UA with tooltip (keep existing behavior); right-align timestamps.
- Owner as a quiet tag; `type` as a small neutral pill.
- `Export` = secondary/ghost button, not the stock green `success`; `Delete`/batch = danger but secondary weight, with confirm.
- Consider a date-range filter as a future addition (not present today).
- Empty state: "No sign-in activity".

## Copy
- Page title: "Sign-in log" (replace "LoginLog")
- Filter: "User"
- Buttons: "Filter", "Delete selected", "Export CSV"
- Columns: "ID", "Owner", "Client", "Device", "UUID", "IP", "Type", "Platform / UA", "Time", "Actions"
- Empty state: "No sign-in activity"
