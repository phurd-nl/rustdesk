# Login History
Route `/my/login_log` · `src/views/my/login_log/index.vue` · Audience: My (the tech's own sign-in events)

## Purpose
Shows the technician's own sign-in / session events — which client, device, IP, and platform — so they can review and clear their login history.

## Layout & content
Top→bottom:

1. **Toolbar card** — Filter button + "Batch delete" button.
2. **Table card** — bordered, row-selectable. Columns:
   - selection checkbox
   - **client** — client app/channel (width 120)
   - **Peer** — device id (`device_id`, falling back to the joined `peer.id`)
   - **uuid**
   - **ip** (width 150)
   - **type** (width 100)
   - **Platform/UA** — platform or user-agent string (truncated, tooltip)
   - **Created at**
   - **Actions**: Delete
3. **Pagination card** — prev/pager/next, sizes 10/20/50/100, jumper.

## How it works
- `useRepositories('my')` from `views/login/log.js`: `getList` on mount + re-activation; page/size watches.
- **Delete** → removes a single log entry.
- **Batch delete** → collects checked rows and calls `batchdel` (no-op if nothing selected).
- Read-only audit data; no create/edit.

## States
- **Empty:** stock "No Data".
- **Loading:** table spinner.
- **Error:** silent.

## Design direction
- Light theme; this is an **audit log**, so density is fine — but format it for scanning, not raw dumps. Lead with **Created at** (relative + exact on hover), then a device/identity column, then IP, then client/platform.
- Collapse `uuid` and the raw `Platform/UA` string into a hover/detail popover — they're rarely scanned and waste width.
- Derive a human **device + OS icon** from the platform/UA where possible instead of showing the raw UA string.
- IP could carry a subtle geo/label later; for now keep monospace.
- Empty state: "No sign-in history yet" panel rather than "No Data".
- "Batch delete" enables only when rows are selected; per-row delete is danger on hover. Hover row wash `#e6f0ff`.
- Lowercase stock column headers ("client", "uuid", "ip", "type") must be cased and renamed (see Copy).

## Copy
- Page / nav: "Login History" (replace "LoginLog")
- Columns: "When" (replace "CreatedAt" for an audit log), "Device" (replace "Peer"), "Client", "IP", "Type", "Platform" (replace "Platform/UA"); "UUID" demoted to detail
- Actions: "Delete"
- Buttons: "Search", "Delete selected" (replace "BatchDelete")
- Empty state: "No sign-in history yet"
