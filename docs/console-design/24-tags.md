# Tags
Route `/my/tag` · `src/views/my/tag/index.vue` · Audience: My (the tech's own device tags)

## Purpose
Manages the colored labels the technician uses to categorize saved devices, scoped per address book.

## Layout & content
Top→bottom:

1. **Filter card** — inline form:
   - Address book (select; "My address book" = id 0, or a named collection)
   - Buttons: Filter, Add
2. **Table card** — bordered. Columns:
   - **ID**
   - **Address book** — collection name ("My address book" for id 0)
   - **Name**
   - **Color** — a swatch: a colored dot inside a neutral chip
   - Created at / Updated at
   - **Actions**: Edit, Delete
3. **Pagination card** — prev/pager/next, sizes 10/20/50/100, jumper.
4. **Create/Update dialog** — Address book (select), Name (required), Color (required; `el-color-picker` with alpha, plus a live swatch preview that tracks the picker via `activeChange`). Submit/Cancel.

## How it works
- `useRepositories('my')`: `getList` on mount + re-activation; page/size watches; `getCollectionList` populates the address-book selects.
- **Add/Edit** → dialog → submit create/update.
- **Delete** → confirm → remove → reload.
- Color picker supports alpha; the preview dot updates live as the color changes (`currentColor`).
- Tags are filtered/created against a chosen collection (`collection_id`).

## States
- **Empty:** stock "No Data".
- **Loading:** table spinner.
- **Error:** silent.

## Design direction
- Light theme; short list — a **table works**, but each tag row should preview as it will actually appear: render the **tag as a real chip** (its color as the chip background or a leading color dot + name), not just a raw swatch + separate name cell.
- Keep the color swatch in the editor; in the list, merge Name + Color into one chip cell.
- Consider offering a small **preset palette** in the editor aligned to the design tokens (blue `#0559c9`, success `#27a35a`, danger `#f03a3a`, brand-orange reserved for the N mark only) so tags stay on-brand, while still allowing custom colors.
- "Add" → primary blue (not stock red). Hover row wash `#e6f0ff`. Delete danger on hover.
- Demote Created/Updated timestamps to a tooltip or detail row.

## Copy
- Page / nav: "Tags"
- Columns: "ID", "Address book", "Name", "Color", "Created", "Updated", "Actions"
- Filter label: "Address book"; buttons "Search", "New tag" (replace "Add")
- Actions: "Edit", "Delete"
- Dialog: title "New tag" / "Edit tag"; fields "Address book", "Name", "Color"; "Save"/"Cancel"
- Default address-book option: "My address book"
