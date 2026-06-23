# Tags (Admin)
Route `/tag` · `apiserver-web/src/views/tag/index.vue` · Audience: System (admin-only)

## Purpose
Admin view of all address-book tags across every user. Tags are named, color-coded labels scoped to a user's address book (or a specific collection); admins create, recolor, edit, and delete them.

## Layout & content
Three stacked cards.

1. **Filter bar**: Owner (user select, clearable), Address Book Name (collection select; 0 = My Address Book) + buttons Filter, Add.
2. **Table**:
   - ID
   - Owner (user tag)
   - Address Book Name (collection name; "My Address Book" when `collection_id === 0`)
   - Name (the tag name)
   - Color (swatch — a colored dot inside a neutral box)
   - Created At
   - Updated At
   - Actions: Edit, Delete
3. **Pagination**: prev/pager/next, page-size (10/20/50/100), jumper.

Dialog — **Create/Update tag**:
- Owner (user select, required)
- Address Book Name (collection select; 0 = My Address Book, required)
- Name (text, required)
- Color (color picker with alpha + live swatch preview, required)

## How it works
- Uses `useRepositories('admin')` from `views/tag/index`. Loads all users on mount; collection list reloads when owner changes (`changeUser`, `changeUserForUpdate`).
- On mount + `onActivated`: loads the tag list. Filter resets page; page/page_size watched.
- Add → dialog; Edit → pre-filled. Submit chooses create vs update by `id`.
- Color picker: `activeChange` updates a `currentColor` live preview while dragging.
- Delete: confirm → remove → refetch.
- Permissions: admin-only.

## States
- Empty: empty table body.
- Loading: `v-loading` on table.
- Error: silent.

## Design direction
- Low-frequency admin surface — keep airy.
- Render each tag as a **chip in its own color** (name on a tinted background derived from the tag color) in both the table Name cell and anywhere tags appear (cross-link with Address Book Entries, page 35) — the stock UI shows name and color in separate columns, which reads as two facts about one thing. Merge them.
- Owner / Address Book → pills (`accent-wash`/`primary`); "My Address Book" neutral muted.
- Color picker: keep alpha; show the resulting chip preview (not just a dot) so admins see the real rendered tag.
- "Add" as a quiet secondary button.

## Copy
- Title: "Tags"
- Subhead: "Color labels for entries in users' address books."
- Filter: "Owner", "Address Book"; buttons "Filter" → "Apply", "Add" → "Add tag"
- Columns: "Owner", "Address Book", "Name", "Color", "Created At", "Updated At", "Actions"
- "My Address Book" stays as-is.
- Form: "Owner", "Address Book", "Name", "Color"
- Empty: "No tags yet."
