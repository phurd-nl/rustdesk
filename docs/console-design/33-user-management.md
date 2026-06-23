# User Management
Routes `/user` (list) + `/user/edit/:id` (add/edit form) · `apiserver-web/src/views/user/index.vue`, `apiserver-web/src/views/user/edit.vue` · Audience: System (admin-only)

## Purpose
The console where an admin manages console/account users — including **promoting a user to admin** and **enabling/disabling** an account. This is the key NextSession workflow for granting an SSO-provisioned user administrative access.

## Layout & content

### List page (`index.vue`)
Three stacked cards.

1. **Filter bar**: Username (text) + buttons Filter, Add, Export.
2. **Table**:
   - ID
   - Username
   - Email
   - Nickname
   - Group (tag, resolved from group list; "-" if none)
   - **Status** — inline toggle switch (on = Enabled `1`, off = Disabled `2`); flipping it persists immediately
   - Remark
   - Created At
   - Updated At
   - Actions (width 650): User Tags, User Address Book, Edit, Reset Password (warning), Delete (danger)
3. **Pagination**: prev/pager/next, page-size (10/20/50/100), jumper.

### Add/Edit form (`edit.vue`)
Single form card, reached via route (saves with `router.back()`):
- Username (text, **required**)
- Email (text, optional)
- Nickname (text)
- Group (select, **required**)
- **Is Admin** (toggle switch, `true`/`false`) — promotes/demotes the user to console admin
- **Status** (toggle switch, Enabled `1` / Disabled `2`, **required**) — enables/disables the account
- Remark (text)
- Buttons: Cancel (router.back), Submit

## How it works
- **List load**: on mount loads groups (`api/group`, page_size 9999) and the user list. Filter resets to page 1.
- **Status toggle (inline, list)**: flipping the switch calls `update(row)` directly — no confirm dialog in current stock — then toasts and refetches. (Reframe: add a confirm for Disable.)
- **Reset Password**: `useChangePwd` flow (warning button).
- **Delete**: `useDel().del(row.id)` then refetch.
- **User Tags / User Address Book**: navigate to that user's tags / address-book views.
- **Export**: `toExport` dumps the user list.
- **Add/Edit form**: `useGetDetail(id)` loads the record (when `id > 0`) and the groups select; `useSubmit` validates (username, group_id, status required) then calls `create` or `update` by route id, success toast, `router.back()`.
- **is_admin** and **status** are set on this form (and status also inline on the list). Both POST through the same user `update` endpoint.
- Permissions: admin-only route; the component does not guard the current admin from disabling/demoting themselves (call this out as a redesign safeguard).

## States
- Empty: empty table body.
- Loading: `v-loading` on table.
- Error: silent (`catch(_ => false)`); status toggle can visually flip even if the save failed — reframe to revert on error.

## Design direction
- This is a **System / governance** surface — treat role and status as first-class badges, not bare switches.
  - **Admin badge**: a distinct pill (e.g. `primary #0559c9` text on `accent-wash #e6f0ff`, or a subtle filled blue) shown in a Role column on the list. Non-admins show "Member" in muted.
  - **Status**: render as a status pill in the list — Enabled = `success #27a35a` dot + label, Disabled = `muted #646e78` / `danger #f03a3a` label. Keep an explicit toggle inside Edit; on the list, prefer a labeled toggle or a confirm-on-disable.
- Add a **Role** column to the list (stock hides admin status entirely on the list — admins can only see it by opening Edit). Surfacing it is important since promoting SSO users to admin is a core flow.
- In the Edit form, group **Is Admin** and **Status** into an "Access" section, visually separated from profile fields (Username/Email/Nickname), with helper text: "Admins can manage all users, devices, and settings."
- Add a self-action guard: warn (or block) when an admin disables or demotes their own account.
- Reset Password → quiet `warning #f5a623` accent; Delete → `danger #f03a3a`, ideally behind an overflow menu.

## Copy
- List title: "Users"
- Filter: "Username", buttons "Filter" → "Apply", "Add" → "Add user", "Export"
- Columns: "Username", "Email", "Nickname", "Group", "Role" (new), "Status", "Remark", "Created At", "Updated At", "Actions"
- Actions: "User Tags" → "Tags", "User Address Book" → "Address books", "Edit", "Reset Password", "Delete"
- Form labels: "Username", "Email", "Nickname", "Group", "Is Admin" → "Administrator", "Status", "Remark"
- Role values: "Administrator" / "Member"
- Status values: "Enabled" / "Disabled"
- Admin helper: "Administrators can manage all users, devices, groups, and settings."
- Self-guard warning: "You are about to remove your own admin access. Continue?"
- Empty: "No users match this search."
