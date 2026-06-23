# Shared Links
Route `/my/share_record` · `src/views/my/share_record/index.vue` · Audience: My (links this tech has shared)

## Purpose
Lists the web-client share links the technician has created for devices, with their expiry, and lets the tech revoke them.

## Layout & content
Top→bottom:

1. **Toolbar card** — Filter button + "Batch delete" button.
2. **Table card** — bordered, row-selectable. Columns:
   - selection checkbox
   - **ID**
   - **Peer** — the shared device id (`peer_id`)
   - **Created at**
   - **Expiry (seconds)** — a badge: the expire value, or "Forever" if none; styled info when expired, success when active
   - **Actions**: Delete
3. **Pagination card** — prev/pager/next, sizes 10/20/50/100, jumper.

## How it works
- `useRepositories('my')`: `getList` on mount + re-activation; page/size watches.
- `expired(row)` decides the expiry badge style (info = expired, success = still valid).
- **Delete** → revokes a single share link.
- **Batch delete** → revokes all checked rows.
- No create flow here — share links are minted from the Saved Devices page ("Share via Web Client"); this page is the management/revocation surface.

## States
- **Empty:** stock "No Data" — likely common; this list is empty until the tech shares something.
- **Loading:** table spinner.
- **Error:** silent.

## Design direction
- Light theme; keep as a table but make **expiry human-readable**: show "Expires in 2h", "Expired 5m ago", or "Never expires" instead of raw seconds. Reserve the raw seconds for a tooltip.
- Expiry status as a **badge**: active = success `#27a35a`, expired = muted grey `#646e78` (not alarming) — expired is normal, not an error.
- Empty state matters here — replace "No Data" with a friendly panel: "No shared links yet. Share a device from Saved Devices to create one," with a link to that page.
- "Batch delete" should be a quiet danger action that only enables when rows are selected; per-row Delete is danger on hover.
- Hover row wash `#e6f0ff`.

## Copy
- Page / nav: "Shared Links" (replace "ShareRecord")
- Columns: "ID", "Device" (replace "Peer"), "Created", "Expiry", "Actions"
- Expiry badge: "Never expires" (replace "Forever"); otherwise relative ("Expires in …" / "Expired")
- Buttons: "Search", "Delete selected" (replace "BatchDelete"), "Revoke" (replace per-row "Delete")
- Empty state: "No shared links yet", body "Share a device from Saved Devices to create a link."
