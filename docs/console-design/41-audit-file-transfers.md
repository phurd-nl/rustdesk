# Audit · File Transfers
Route `/auditFile` · `src/views/audit/fileList.vue` · Audience: System (admin-only)

## Purpose
Audit trail of files moved during sessions — direction, file names/sizes, count, and path — so an admin can review what was transferred where.

## Layout & content
Top→bottom:

1. **Toolbar card** — `Peer` text filter + `FromPeer` text filter + `Filter` + `BatchDelete` + `Export`.
2. **Transfers table** (max-height 750, scrolls) — row-select checkbox, plus:
   - **ID** (`id`)
   - **Peer** (`peer_id`)
   - **FromPeer** (`from_peer`)
   - **FromName** (`from_name`)
   - **Ip** (`ip`)
   - **Type** (`type`) — tag with direction: `1` = "ToRemote → peer_id" (warning), else "ToLocal → from_peer"
   - **Num** (`num`) — number of files
   - **FileInfo** — nested mini-table of file name + size (`sizeFormat`), showing first 3 (`showDirFileNum`); a "More(N)" button opens the full-list dialog. Single-file rows (`is_file`) just show the size.
   - **Path** (`path`) — overflow-tooltip
   - **uuid** (`uuid`) — overflow-tooltip
   - **CreatedAt** (`created_at`)
   - **Actions** (fixed right) — `Delete` (danger)
3. **Pagination** — 10/20/50/100.
4. **All-files dialog** — full list of files for a row: Index, FileName, Size; `Close` button.

## How it works
- `useFileRepositories()` from `@/views/audit/reponsitories`.
- `getList` on mount/activate and page change; `handlerQuery` resets to page 1.
- Filters: `peer_id`, `from_peer`.
- `showAllFile(files)` populates and opens the dialog when a directory has more than 3 files.
- `sizeFormat` renders human-readable byte sizes.
- **Delete** single; **BatchDelete** checked (no-op if empty); **Export** downloads.

## States
- **Empty:** stock "No Data" — reframe.
- **Loading:** table spinner.
- **Error:** swallowed.
- **No-permission:** admin-only.

## Design direction
- Light canvas; white cards, 14px radius; system-UI font.
- This row is information-dense — keep the **nested file mini-table** but style it as a quiet inset (lighter divider, monospace file names, right-aligned sizes); cap at 3 with a "+N more" text link, not a heavy primary button.
- **Direction** as an "A → B" cell with an arrow: ToRemote (upload) vs ToLocal (download); use a small directional icon + warning `#f5a623` for uploads to remote.
- `Num` as a small count badge.
- Full-file dialog: clean modal, sticky header, scroll body; total size summary in the footer.
- `Export` ghost; `Delete`/batch danger, secondary weight, confirm.
- Empty state: "No file-transfer records".

## Copy
- Page title: "File-transfer audit" (replace "AuditFileLog")
- Filters: "To device", "From device"
- Buttons: "Filter", "Delete selected", "Export CSV"
- Columns: "ID", "Direction", "From user", "IP", "Files", "Details", "Path", "UUID", "Time", "Actions"
- Direction tags: "Upload to remote", "Download to local" (replace "ToRemote"/"ToLocal")
- File table: "File name", "Size"; "+{n} more" (replace "More(N)")
- Dialog title: "Files"; columns "#", "File name", "Size"; button "Close"
- Empty state: "No file-transfer records"
