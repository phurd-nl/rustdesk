# Saved Devices (Address Book Entries)
Route `/my/address_book` · `src/views/my/address_book/index.vue` · Audience: My (devices the tech has saved)

## Purpose
Lists the individual devices the technician has saved into their address books, with the tags, aliases, and collection each belongs to, plus connect/share/edit actions.

## Layout & content
Top→bottom:

1. **Filter card** — inline form:
   - Address book (select; "My address book" = id 0, or a named collection)
   - ID (text)
   - Username (text)
   - Hostname (text)
   - Buttons: Filter, Add, "Batch edit tags"
2. **Table card** — bordered, row-selectable. Columns:
   - selection checkbox
   - **ID** — leading platform icon + ID + copy icon
   - **Address book** — collection name ("My address book" for id 0)
   - Username
   - Hostname
   - **Tags**
   - Alias
   - Version (`peer.version`, joined from live peer data)
   - Hash (truncated, tooltip)
   - **Actions** (fixed right, wide): Connect, Web Client + "Share via Web Client" (only if `appConfig.web_client`), Edit, Delete
3. **Pagination card** — prev/pager/next, sizes 10/20/50/100, jumper.
4. **Create/Update dialog** — Address book (select), ID (required), Username, Alias, Hash, Hostname, Platform (Windows/Linux/Mac OS/Android), Tags (multi-select). Changing the collection reloads its tag list. Submit/Cancel.
5. **Share-by-Web-Client dialog** — embeds `shareByWebClient.vue` (id + hash) to mint a shareable web-client link.
6. **Batch-edit-tags dialog** — Tags multi-select applied to all checked rows via `batchUpdateTags`.

## How it works
- `useRepositories('my')`: `getList` loads entries, then calls `simpleData({ids})` to enrich each row with live peer info (version, etc.). Loads on mount + tab re-activation; page/size watches.
- **Connect** → `connectByClient(id)`; **Web Client** → `toWebClientLink(row)`.
- **Add/Edit** → name/detail dialog → create/update; changing the address book in the dialog refreshes the available tags for that collection.
- **Delete** → confirm → remove → reload.
- **Batch edit tags** → checkboxes collect `row_id`s → tag dialog → `batchUpdateTags` → reload.
- **Share via Web Client** → opens the share dialog seeded with the row's id + hash.

## States
- **Empty:** stock "No Data".
- **Loading:** table spinner; peer-enrichment is a silent second fetch.
- **Error:** silent.

## Design direction
- Light theme; keep as a **table** (this is the primary working surface) but reduce columns: lead with platform-icon + ID, then Alias/Hostname, Tags, Address book, Actions. Push Hash/Username/Version into a detail/hover view.
- Render **Tags as colored chips** using each tag's color (see Tags page) rather than a comma string — this is the most valuable visual upgrade here.
- Platform icon stays but recolor to foreground `#1b1f24`; ID monospace; copy icon on hover.
- Hover row wash `#e6f0ff`. Primary action **Connect** in primary blue; Edit/Share as ghost; Delete danger on hover/menu.
- Collapse the very wide (600px) action column into a few primary buttons + an overflow menu.
- "Add" button → primary blue (not stock red).

## Copy
- Page / nav: "Saved Devices" (replace "AddressBook")
- Columns: "ID", "Address book", "User", "Hostname", "Tags", "Alias", "Version", "Hash", "Actions"
- Filter labels: "Address book", "Device ID", "User", "Hostname"; buttons "Search", "Add device", "Edit tags"
- Actions: "Connect", "Web client", "Share link" (replace "ShareByWebClient"), "Edit", "Delete"
- Dialog: title "Add device" / "Edit device"; fields "Address book", "Device ID", "User", "Alias", "Hash", "Hostname", "Platform", "Tags"; "Save"/"Cancel"
- Default address-book option: "My address book"
