# Address Book Entries (Admin)
Route `/address-book` · `apiserver-web/src/views/address_book/index.vue` · Audience: System (admin-only)

## Purpose
Admin view of the individual peer entries inside every user's address books. Admins can filter by owner/collection, edit an entry's metadata and tags, connect to it, or delete it.

## Layout & content
Three stacked cards.

1. **Filter bar**: Owner (user select, clearable), Address Book Name (collection select; 0 = My Address Book), Id (text), Username (text), Hostname (text) + buttons Filter, Add.
2. **Table**:
   - ID (platform icon + id + copy-to-clipboard icon)
   - Owner (user tag)
   - Address Book Name (collection name; "My Address Book" when `collection_id === 0`)
   - Username
   - Hostname
   - Tags
   - Alias
   - Version (`peer.version`)
   - Hash
   - Actions (fixed right, width 500): Link, Web Client (if `appConfig.web_client`), Edit, Delete
3. **Pagination**: prev/pager/next, page-size (10/20/50/100), jumper.

Dialog — **Create/Update entry**:
- Owner (user select, required)
- Address Book Name (collection select; 0 = My Address Book) — reloads collection list when owner changes
- ID (text, required)
- Username
- Alias
- Hash
- Hostname
- Platform (select)
- Tags (multi-select, from the tag list)

## How it works
- Uses `useRepositories('admin')` from `views/address_book/index`. Reads `route.query.user_id` to pre-filter by owner (deep link from the Users page).
- On mount + `onActivated`: loads all users and the entry list; collection list reloads on owner change (`changeQueryUser`, `changeUserForUpdate`, `changeCollectionForUpdate`).
- Filter resets page; page/page_size watched.
- Add → dialog; Edit → pre-filled. Submit chooses create vs update by `row_id`.
- Delete: confirm → remove → refetch.
- Link / Web Client: `connectByClient(id)` / browser client.
- Copy icon: `handleClipboard(row.id)`.
- Stock carries a commented "editing here may desync data" warning tag — entries normally sync from clients, so admin edits are a power-user escape hatch.
- Permissions: admin-only.

## States
- Empty: empty table body.
- Loading: `v-loading` on table.
- Error: silent.

## Design direction
- Dense, wide table — second only to Devices. White card, `size="small"`-equivalent density, and wrap in `overflow-x:auto` so the fixed action column never forces page-level horizontal scroll.
- Platform icon → keep, tinted to `foreground #1b1f24`; copy icon muted → primary on hover.
- Owner / Address Book Name → pills (`accent-wash`/`primary`). "My Address Book" as a neutral muted pill.
- Tags → colored chips (reuse tag colors from page 36) rather than a plain comma list.
- Action column: keep **Connect** primary blue; fold Web Client / Edit / Delete into an overflow menu.
- Add a subtle inline note near the table: editing entries here can desync from the client's copy — frame as advanced/admin-only.

## Copy
- Title: "Address Book Entries"
- Subhead: "Devices saved in users' address books. Entries normally sync from clients — edit with care."
- Filter: "Owner", "Address Book", "ID", "Username", "Hostname"; buttons "Filter" → "Apply", "Add" → "Add entry"
- Columns: "Owner", "Address Book", "Username", "Hostname", "Tags", "Alias", "Version", "Hash", "Actions"
- "My Address Book" stays as-is.
- Actions: "Link" → "Connect", "Edit", "Delete"
- Form: "Owner", "Address Book", "ID", "Username", "Alias", "Hash", "Hostname", "Platform", "Tags"
- Empty: "No address book entries match these filters."
