# Device Group Management
Route `/device-group` · `apiserver-web/src/views/group/deviceGroupList.vue` · Audience: System (admin-only)

## Purpose
Manage device groups — labels used to organize peers (referenced by the `group_id` column on the Devices page). Simpler than permission Groups: name only, no type.

## Layout & content
Three stacked cards.

1. **Filter bar** (card): action buttons only — Filter, Add.
2. **Table** (card):
   - ID
   - Name
   - Created At
   - Updated At
   - Actions: Edit, Delete
3. **Pagination** (card): prev/pager/next, page-size (10/20/50/100), jumper.

Dialog — **Create/Update device group**:
- Name (text, required).

## How it works
- On mount + `onActivated`: `list` from `api/device_group`.
- Filter resets to page 1; page/page_size watched.
- Add → empty dialog; Edit → pre-filled. Submit chooses create vs update by `id`; toast + refetch.
- Delete: confirm → `remove({id})` → toast + refetch.
- Note: the form `reactive` carries a vestigial `type` field that the UI never exposes (copy-paste from permission Groups). Ignore in redesign.
- Permissions: admin-only route.

## States
- Empty: empty table body.
- Loading: `v-loading` on table.
- Error: silent.

## Design direction
- Trivial CRUD list — keep minimal. White card, airy rows.
- This page and permission "Groups" look near-identical in stock; differentiate with clear titles and an explanatory subhead so admins don't confuse "Device Groups" (organizing peers) with "Groups" (sharing scopes).
- "Add" as a quiet secondary button.

## Copy
- Title: "Device Groups"
- Subhead: "Labels for organizing devices in the inventory."
- Buttons: "Filter" → "Apply", "Add" → "Add device group"
- Columns: "Name", "Created At", "Updated At", "Actions"
- Empty: "No device groups yet."
