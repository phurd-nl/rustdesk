# Group Management
Route `/group` · `apiserver-web/src/views/group/index.vue` · Audience: System (admin-only)

## Purpose
Manage permission groups that scope which users/devices can see and share with each other. Each group is either a Common (isolated) or Shared group.

## Layout & content
Three stacked cards.

1. **Filter bar** (card): only action buttons — Filter, Add. (Name filter is commented out in stock.)
2. **Table** (card):
   - ID
   - Name
   - Type (renders "Common Group" for type 1, "Shared Group" otherwise)
   - Created At
   - Updated At
   - Actions: Edit, Delete
3. **Pagination** (card): prev/pager/next, page-size (10/20/50/100), jumper.

Dialog — **Create/Update group**:
- Name (text, required)
- Type (radio group, required): Common Group / Shared Group, each with an explanatory note line.

## How it works
- On mount + `onActivated`: `list` from `api/group`.
- Filter resets to page 1 then queries; page/page_size watched.
- Add → dialog with empty form (type defaults to 1/Common). Edit → dialog pre-filled with row id/name/type.
- Submit: create vs update chosen by presence of `id`; API `create`/`update`; success toast + refetch.
- Delete: confirm dialog → `remove({id})` → toast + refetch.
- Permissions: admin-only route.

## States
- Empty: empty table body.
- Loading: `v-loading` on table.
- Error: silent (`catch(_ => false)`).

## Design direction
- Small, low-frequency table — keep it airy, not dense. White card, 14px radius.
- Type → badge: "Shared" in `accent-wash #e6f0ff`/`primary #0559c9`; "Common" in neutral muted badge.
- In the create dialog, render the two type options as **selectable radio cards** (name in foreground `#1b1f24`, note in `muted #646e78`) rather than stock stacked radios — the choice is consequential and benefits from the extra explanation surface.
- "Add" should be a quiet secondary button (not stock `danger` red).

## Copy
- Title: "Groups"
- Buttons: "Filter" → "Apply", "Add" → "Add group"
- Columns: "Name", "Type", "Created At", "Updated At", "Actions"
- Type values: "Common Group", "Shared Group"
- Type notes: keep the existing `CommonGroupNote` / `SharedGroupNote` English strings (members isolated vs. shared visibility).
- Empty: "No groups yet. Add a group to scope sharing."
