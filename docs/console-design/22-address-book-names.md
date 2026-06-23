# Address Books (Collections)
Route `/my/address_book/collection` · `src/views/my/address_book/collection.vue` · Audience: My (the tech's own address books)

## Purpose
Manages the named groupings ("collections") the technician uses to organize saved devices, and lets them set per-collection sharing rules.

## Layout & content
Top→bottom:

1. **Toolbar card** — Filter button + "Add" button.
2. **Table card** — preceded by a warning tag rendering `MyAddressBookTips` (the always-present default "My address book" caveat). Columns:
   - **Name**
   - **Created at**
   - **Actions** (fixed right): "Share rules", "Edit", "Delete"
   - The implicit default row (id 0, "My address book") is **prepended on page 1 only** and has no action buttons (actions render only when `id > 0`).
3. **Pagination card** — prev/pager/next, sizes 10/20/50/100, jumper.
4. **Create/Update dialog** — single field: Name (required). Submit/Cancel. Title switches Create vs Update by presence of `id`.
5. **Share-rules dialog** — large modal embedding `address_book/rule.vue` with `:is_my="1"`; manages who a collection is shared with.

## How it works
- Logic comes from the shared `useRepositories('my')` collection composable; `getList` on mount, page-change watch, page-size resets to page 1.
- The default "My address book" row is injected client-side (computed) so it always appears first on page 1; it cannot be edited or deleted.
- **Add/Edit** opens the name dialog → `submit` create/update.
- **Delete** → confirm → remove → reload.
- **Share rules** stores the clicked row and opens the rule editor.

## States
- **Empty:** the default "My address book" row still shows on page 1, so the list is never truly empty; named collections below it may be absent.
- **Loading:** table spinner.
- **Error:** silent.

## Design direction
- Light cards. This is a short, low-density list — a **table is fine**, but consider a **card/list hybrid** where each collection is a row with its name, device count (if available), created date, and a kebab menu.
- The default "My address book" row should read as a **pinned, system row**: a subtle "Default" pill, muted, no destructive actions — visually distinct from user-created collections.
- Replace the red warning `el-tag` with a quiet **info banner** in accent wash `#e6f0ff` (not danger red) explaining what "My address book" is.
- "Add" should be **primary blue**, not the stock red `danger`. "Delete" stays danger `#f03a3a` but only on hover/menu.
- "Share rules" is the differentiating action — give it primary emphasis.

## Copy
- Page / nav: "Address Books" (replace "AddressBookName" / "Collection")
- Columns: "Name", "Created", "Actions"
- Default row label: "My address book" + a "Default" pill
- Banner (replace `MyAddressBookTips`): "Your personal address book holds devices saved only to you. Create additional address books to group and share devices."
- Buttons: "New address book" (replace "Add"), "Edit", "Delete", "Sharing rules" (replace "ShareRules")
- Dialog: title "New address book" / "Edit address book", field "Name", "Save"/"Cancel"
