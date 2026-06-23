# Device Management
Route `/peer` · `apiserver-web/src/views/peer/index.vue` · Audience: System (admin-only)

## Purpose
The master inventory of every RustDesk peer/device known to the server. Admins search, edit, import/export, connect to, and bulk-file devices into address books.

## Layout & content
Three stacked cards top→bottom.

1. **Filter bar** (card): inline form with fields — ID, Hostname, Last Online Time (select), Username, IP — plus action buttons: Filter, Add, Export, Import (popover with CSV drag-upload), Batch Delete, Batch Add to Address Book.
2. **Table** (card): a column-settings gear button (top-right) opens a dialog to toggle/reorder columns; selection checkboxes on the left. Default columns:
   - ID (with copy-to-clipboard icon)
   - CPU
   - Hostname
   - Memory
   - OS
   - Last Online Time (relative "x ago" + colored status dot)
   - Last Online IP
   - Username
   - Group (tag, resolved from group list)
   - UUID
   - Version
   - Alias
   - Created At
   - Updated At
   - Actions (fixed right): Link, Web Client (only if `appConfig.web_client`), Add to Address Book, Edit, Delete
3. **Pagination** (card): prev/pager/next, page-size selector (10/20/50/100), jumper.

Dialogs:
- **Create/Update device form** — ID (required), Group (select), Username, Hostname, CPU, Memory, OS, UUID, Version, Alias.
- **Add to Address Book** — embeds `createABForm` with the clicked peer.
- **Batch Add to Address Book** — Owner (user select), Address Book Name (collection select; 0 = My Address Book).
- **Column Setting** — checkbox + up/down reorder per column; persisted to `localStorage` (`peer_visible_columns`).

## How it works
- On mount: loads group list (`api/device_group`, page_size 999), peer list (`api/peer`), all users (`loadAllUsers`), and collections for the batch dialog. `onActivated` re-fetches the list (keep-alive friendly).
- **Filter**: Filter button resets to page 1 then queries; query is debounced through page/page_size watchers.
- **Last Online dot**: green if last seen < 60s ago, red otherwise. Time filter offers Minutes/Hours/Days less-than and Minutes/Hours/Days/Months ago buckets.
- **Add/Edit**: dialog form; create vs update chosen by presence of `row_id`. API `create`/`update`.
- **Delete**: confirm dialog → `remove({row_id})`.
- **Export**: re-queries with page_size 10000, strips `user`/`user_id`, converts to CSV (`peers.csv`).
- **Import**: CSV drag-upload, parsed client-side; columns `id,cpu,hostname,memory,os,username,uuid,version,group_id`; each row POSTed via `create` in parallel.
- **Batch Delete**: requires selection → confirm → `batchRemove({row_ids})`.
- **Batch Add to AB**: requires selection; picks owner + collection → `batchCreateFromPeers`.
- **Link / Web Client**: `connectByClient(id)` launches the native client; Web Client opens the browser client.
- **Add to Address Book** (single): opens `createABForm` dialog for that peer.
- Permissions: admin-only route; no per-row permission gating in the component.

## States
- Empty: table renders empty body.
- Loading: `v-loading` overlay on the table.
- Error: API failures swallowed (`catch(_ => false)`) — no list update, no toast. (Reframe: surface a real error state.)

## Design direction
- This is the densest table in the console. Use a **white card on #f6f8fa**, 14px radius, soft shadow; table at `size="small"` density with comfortable 8px row padding.
- Last-online status dot → token dots: online (< 60s) = `success #27a35a`, offline = `muted #646e78` (reserve `danger #f03a3a` for true failures, not "offline").
- Group → pill badge using `accent-wash #e6f0ff` bg / `primary #0559c9` text.
- The action column has 5+ buttons and is the worst offender for clutter. Collapse secondary actions (Add to Address Book, Web Client, Delete) into a kebab/overflow menu; keep **Connect** as the single primary blue button. Edit as a quiet ghost button.
- Filter bar: convert to a single-line filter row with a primary "Filter" button (blue) and a separate quiet "+ Add Device" button. Move Export/Import/Batch under a "More" menu.
- Column-settings gear → keep, but label it "Columns".
- ID copy icon → muted, hover to `primary`.

## Copy
- Title: "Devices"
- Filter fields: "ID", "Hostname", "Last seen", "Username", "IP"
- Buttons: "Filter" → "Apply", "Add" → "Add device", "Export", "Import", "Batch Delete" → "Delete selected", "Batch Add to AB" → "Add selected to address book"
- Columns: "Last Online Time" → "Last seen", "Last Online Ip" → "Last IP", "Os" → "OS", "Uuid" → "UUID"
- Actions: "Link" → "Connect", "AddToAddressBook" → "Add to address book", "Edit", "Delete"
- Import hint: "Drop a CSV file here, or click to upload. Columns: id, cpu, hostname, memory, os, username, uuid, version, group_id."
- Empty: "No devices match these filters."
