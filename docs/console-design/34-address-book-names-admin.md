# Address Book Names (Admin)
Route `/address-book-collection` · `apiserver-web/src/views/address_book/collection.vue` · Audience: System (admin-only)

## Purpose
Admin view of all named address-book "collections" across every user. A collection is a named address book owned by a user; admins can create, rename, delete, and edit its share rules.

## Layout & content
Three stacked cards.

1. **Filter bar**: Owner (user select, clearable) + buttons Filter, Add.
2. **Table**:
   - ID
   - Owner (user tag, resolved from all-users list)
   - Address Book (the collection name)
   - Created At
   - Actions (fixed right, width 600): Share Rules, Edit, Delete
3. **Pagination**: prev/pager/next, page-size (10/20/50/100), jumper.

Dialogs:
- **Create/Update collection**: Owner (user select, required), Name (text, required).
- **Share Rules**: full-width (80%) dialog embedding `rule.vue` (`Rule`) with `is_my=0` — manages who the collection is shared with.

## How it works
- Uses the shared `useRepositories('admin')` collection composable; `listQuery.is_my = 0` scopes to the admin (all-collections) view.
- On mount + `onActivated`: loads all users (`loadAllUsers`) and the collection list.
- Filter resets page; page/page_size watched.
- Add → empty dialog; Edit → pre-filled. Submit chooses create vs update by `id`.
- Delete: confirm → remove → refetch.
- Share Rules: opens the rule editor dialog for the selected collection.
- Permissions: admin-only; admins act on behalf of any owner.

## States
- Empty: empty table body.
- Loading: `v-loading` on table.
- Error: silent.

## Design direction
- White card, airy rows; this is a low-frequency admin surface.
- Owner → user pill (`accent-wash #e6f0ff` / `primary #0559c9`); pair with a small avatar/initials chip for scanability when many owners exist.
- "Share Rules" is the meaningful action — make it the primary blue button; Edit quiet, Delete in overflow.
- The Share Rules dialog is large (80% width) — give it a clear titled header and a scrollable body (`overflow-x:auto`) so wide rule tables don't push the page sideways.
- Clarify naming: this page manages **named address books** (collections), distinct from the entries inside them (see Address Books Admin / page 35).

## Copy
- Title: "Address Books"
- Subhead: "Named address books owned by users. Manage sharing here."
- Filter: "Owner", buttons "Filter" → "Apply", "Add" → "Add address book"
- Columns: "Owner", "Address Book" → "Name", "Created At", "Actions"
- Actions: "Share Rules" → "Sharing", "Edit", "Delete"
- Form: "Owner", "Name"
- Empty: "No address books yet."
