# Audit · Connections
Route `/auditConn` · `src/views/audit/connList.vue` · Audience: System (admin-only)

## Purpose
Audit trail of remote-control connections between peers — who connected to whom, from what IP, when it opened and closed.

## Layout & content
Top→bottom:

1. **Toolbar card** — `Peer` text filter + `FromPeer` text filter + `Filter` + `BatchDelete` + `Export`.
2. **Connections table** — row-select checkbox, plus:
   - **ID** (`id`)
   - **Peer** (`peer_id`) — the controlled device
   - **FromPeer** (`from_peer`) — the controlling device
   - **FromName** (`from_name`)
   - **Ip** (`ip`)
   - **Type** (`type`) — tag: `1` = "File" (warning), else "Common"
   - **uuid** (`uuid`) — overflow-tooltip
   - **CreatedAt** (`created_at`) — session start
   - **CloseTime** (`close_time`) — session end
   - **Actions** — `Delete` (danger)
3. **Pagination** — 10/20/50/100.

## How it works
- `useRepositories()` from `@/views/audit/reponsitories`.
- `getList` on mount/activate and page change; `handlerQuery` resets to page 1.
- Two free-text filters: `peer_id` and `from_peer`.
- **Delete** single; **BatchDelete** checked rows (no-op if empty).
- **Export** (`toExport`) downloads the audit data.

## States
- **Empty:** stock "No Data" — reframe.
- **Loading:** table spinner.
- **Error:** swallowed.
- **No-permission:** admin-only.

## Design direction
- Light canvas; white cards, 14px radius; system-UI font.
- Dense audit table — compact rows; monospace for `peer_id`/`from_peer`/`ip`/`uuid`.
- **Connection direction** is the key story: render FromPeer → Peer as a single "A → B" cell with an arrow glyph rather than two separate columns the reader has to mentally pair.
- `Type` pill: "File transfer" = warning `#f5a623`, "Remote control" = neutral blue/grey.
- Show duration (CloseTime − CreatedAt) as a derived column where data allows; mark still-open sessions with a "Live" success pill.
- `Export` = ghost/secondary; `Delete`/batch = danger, secondary weight, with confirm.
- Empty state: "No connection records".

## Copy
- Page title: "Connection audit" (replace "AuditConnLog")
- Filters: "To device", "From device"
- Buttons: "Filter", "Delete selected", "Export CSV"
- Columns: "ID", "From → To", "From user", "IP", "Type", "UUID", "Opened", "Closed", "Actions"
- Type tags: "File transfer", "Remote control" (replace "File"/"Common")
- Empty state: "No connection records"
