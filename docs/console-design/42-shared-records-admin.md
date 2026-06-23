# Shared Records (Admin)
Route `/shareRecord` · `src/views/share_record/index.vue` · Audience: System (admin-only)

## Purpose
Org-wide list of shared-device records (share links a user created for a peer), with their expiry, so an admin can review and revoke any share.

## Layout & content
Top→bottom:

1. **Toolbar card** — `User` filter (select, clearable, all users) + `Filter` + `BatchDelete`.
2. **Shares table** — row-select checkbox, plus:
   - **ID** (`id`)
   - **User** — username tag from `user_id` (the owner)
   - **Peer** (`peer_id`) — the shared device
   - **CreatedAt** (`created_at`)
   - **ExpireTime (Second)** (`expire`) — tag: the value in seconds, or "Forever" when unset; grey `info` when expired, green `success` when valid
   - **Actions** — `Delete` (danger)
3. **Pagination** — 10/20/50/100.

## How it works
- `useRepositories('admin')` — `'admin'` scopes this to all users' shares (vs. the user's own `/my/share_record`).
- `getList` on mount/activate and page change; `handlerQuery` resets to page 1.
- User filter narrows by `user_id`.
- `expired(row)` decides the expiry tag color.
- **Delete** single; **BatchDelete** checked rows (no-op if empty).

## States
- **Empty:** stock "No Data" — reframe.
- **Loading:** table spinner.
- **Error:** swallowed.
- **No-permission:** admin-only.

## Design direction
- Light canvas; white cards, 14px radius; system-UI font.
- The raw `expire` seconds value is unfriendly — render expiry as **human-readable**: "Never" (Forever), "Expired" (muted grey pill), or a relative/absolute time. Status dot+label: valid = success `#27a35a`, expired = muted grey `#646e78`.
- Owner as a quiet tag; `peer_id` monospace.
- "Delete"/revoke = danger but secondary weight, with confirm (single and batch).
- Comfortable density — this is a scan-and-revoke surface, not bulk data.
- Empty state: "No shared devices".

## Copy
- Page title: "Shared devices" (replace "ShareRecord")
- Filter: "Owner"
- Buttons: "Filter", "Revoke selected" (replace "BatchDelete")
- Columns: "ID", "Owner", "Device", "Created", "Expires", "Actions"
- Action: "Revoke" (replace "Delete")
- Expiry values: "Never" (replace "Forever"); drop the raw "(Second)" suffix in the header
- Empty state: "No shared devices"
