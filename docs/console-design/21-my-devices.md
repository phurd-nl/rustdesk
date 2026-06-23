# My Devices
Route `/my/peer` · `src/views/my/peer/index.vue` · Audience: My (devices this tech has connected to / owns)

## Purpose
Lists the remote machines associated with the signed-in technician — their ID, host details, and online status — and lets the tech connect to them or save them into an address book.

## Layout & content
Top→bottom:

1. **Filter card** — inline form:
   - ID (text)
   - Hostname (text)
   - Last online (select of relative ranges: less-than 1 min/hour/day, more-than 1 min/hour/day/month)
   - Buttons: Filter, Export, "Add to address book" (batch)
2. **Table card** — bordered, small density, with row selection checkboxes. Columns:
   - selection checkbox
   - **ID** (with copy-to-clipboard icon)
   - CPU
   - Hostname
   - Memory
   - OS
   - **Last online** — relative time ("3 min ago") + a status dot (green if seen <60s ago, red otherwise)
   - Last online IP
   - Username
   - UUID
   - Version
   - Alias
   - Created at / Updated at
   - **Actions** (fixed right, wide): Connect, Web Client (only if `appConfig.web_client`), "Add to address book", View
3. **Pagination card** — prev/pager/next, page sizes 10/20/50/100, jumper.
4. **View dialog** — read-only device detail form (ID, Username, Hostname, CPU, Memory, OS, UUID, Version).
5. **Add-to-address-book dialog** (single) — pre-filled from the row: Address book (select; "My address book" = id 0, or a named collection), ID, Username, Alias, Hostname, Platform (Windows/Linux/Mac OS/Android), Tags (multi-select). Submit/Cancel.
6. **Batch add-to-address-book dialog** — Address book select + Tags multi-select, applied to all checked rows.

## How it works
- `list(listQuery)` loads on mount, on tab re-activation, and on page change; `Filter` resets to page 1.
- **Connect** → `connectByClient(id)` launches the native client; **Web Client** → `toWebClientLink(row)`.
- **Export** → re-queries with `page_size=10000`, converts to CSV, downloads `peers.csv` (formats last-online to locale string, strips `user_id`/`user`).
- **Add to address book** maps OS string → platform, opens the dialog, submits via the address-book `create` API.
- **Batch add** collects checked `row_id`s and calls `batchCreateFromPeers`.
- Delete actions exist in source but are commented out (not exposed).

## States
- **Empty:** stock "No Data".
- **Loading:** table-level spinner (`v-loading`).
- **Error:** silent (`.catch(_ => false)`).

## Design direction
- This is a dense operational list — keep it a **table**, light theme, but trim the column count. The stock 13 columns are too many: promote ID, Hostname, OS, Last online (status), Alias, Actions; demote CPU/Memory/UUID/Version/IPs/timestamps into the View detail panel or a "more" popover.
- **Status as a badge, not a bare dot in the corner:** show "Online" (green `#27a35a` dot) vs "Offline" (red `#f03a3a` dot) inline with the relative-time text, with the dot leading.
- ID cell: monospace with a subtle copy icon that only highlights on row hover; hover row wash `#e6f0ff`.
- Primary action = **Connect** in primary blue `#0559c9`; secondary actions (View, Add to address book) as ghost buttons; drop the all-green button styling.
- Action column is 500px wide in stock — collapse rarely-used actions into an overflow menu so the table breathes.
- Filters: render the relative-time select as labeled groups ("Online within…" / "Last seen over…"); remove the disabled `---------` separator hack.

## Copy
- Page / nav: "My Devices" (replace "MyPeer")
- Columns: "ID", "CPU", "Hostname", "Memory", "OS", "Last online", "Last IP", "User", "UUID", "Version", "Alias", "Added", "Updated"
- Filter labels: "Device ID", "Hostname", "Last online", buttons "Search", "Export CSV", "Add to address book"
- Status badge text: "Online" / "Offline" (derive from the <60s rule)
- Actions: "Connect", "Web client", "Add to address book", "Details"
- View dialog title: "Device details"
- Add-to-AB dialog: "Save to address book", field "Address book" with default option "My address book", "Device ID", "User", "Alias", "Hostname", "Platform", "Tags", "Save"/"Cancel"
