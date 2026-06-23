# NextSession Console — Design Specs

One `.md` per console page. Hand each file to Claude Design to design that screen.
Every spec assumes the **shared design system + global chrome** below — a tab spec
only describes what is *unique* to that page.

> Source of truth for the look: repo `DESIGN.md`. Source of truth for behavior:
> the Vue component named in each spec (`apiserver-web/src/views/...`).

---

## Design system (tokens)

NextSession matches the NextLink **"Ticketing"** app: a **UniFi-inspired** system —
clean, light, blue-forward, with NextLink **orange demoted to a brand accent**.
The signed-in app chrome is **light**; the **auth screens are a deliberate dark
brand moment** (see `10-19` auth specs).

| Token | Value | Use |
|---|---|---|
| `primary` | `#0559c9` (UniFi blue) | buttons, links, active states |
| `primary-press` | `#0449a6` | pressed/hover primary |
| `background` | `#f6f8fa` | app canvas |
| `card` / `popover` | `#ffffff` | surfaces |
| `foreground` | `#1b1f24` | primary text |
| `muted-foreground` | `#646e78` | secondary text, labels |
| `accent-wash` | `#e6f0ff` | hover/active background |
| `border` | `rgba(17,24,39,.07)` | soft translucent lines |
| `success` | `#27a35a` | online / ok |
| `warning` | `#f5a623` (NextLink orange) | caution |
| `danger` | `#f03a3a` | destructive / offline |
| `brand-orange` | `#f49e1b` | the **N** mark, auth primary only |
| `radius` | `8px` | corners (cards use 14px) |
| sidebar active | `#eef4ff` pill + `#0559c9` text + 3px left bar | |

**Type:** system UI stack (`-apple-system, "Segoe UI", system-ui`). No Inter/Roboto.
**Marks:** orange-gradient disc + folded white **N** (`branding/assets/nextsession-icon.svg`);
wordmark = `NEXT`(orange) + `SESSION`(gray italic).
**Avoid:** dark-slate admin look, gradient-soup backgrounds, emoji, Chinese strings.

---

## Global chrome (every signed-in page)

- **Brand corner** (top-left, over the sidebar): N badge + NextSession wordmark.
- **Top bar:** collapse toggle, current-page context label, spacer, theme toggle,
  language, user chip (`avatar + username + caret`) with a menu (profile / sign out).
- **Sidebar:** white rail, two collapsible groups — **My** (the tech's own data) and
  **System** (admin management; only shown to admins). Active item = `#eef4ff` pill,
  `#0559c9` text, 3px left accent bar. English labels only.
- **Tab strip:** opened pages appear as closeable tabs above the content (the app is
  a multi-tab workspace). Active tab is a white card joined to the content.
- **Content:** `#f6f8fa` canvas, white cards (14px radius, soft shadow), max-width ~1180px.

When SSO-only is on, the **password form is hidden** and a single IdP auto-redirects.

---

## Spec template (each tab file follows this)

```
# <Page Name>
Route · Source component · Audience (My = self / System = admin-only)

## Purpose
1–2 sentences: what this page is for.

## Layout & content
Regions top→bottom. For tables: the columns. For forms: the fields + types.

## How it works
Data it loads, actions/buttons, dialogs, side effects, API calls, permissions.

## States
Empty · loading · error · no-permission.

## Design direction
How to apply the tokens here; density; any reframes from the stock UI.

## Copy
English labels to use (replace Chinese / awkward stock strings).
```

---

## Tab index

### Auth (not in sidebar — dark brand moment)
| # | Page | Component |
|---|---|---|
| 10 | Login | `login/login.vue` |
| 11 | Register | `register/index.vue` |
| 12 | OAuth Login (SSO redirect) | `oauth/login.vue` |
| 13 | OAuth Bind | `oauth/bind.vue` |

### My (the signed-in tech's own data)
| # | Page | Route | Component |
|---|---|---|---|
| 20 | User Info | `/` | `my/info.vue` |
| 21 | My Devices | `/peer` | `my/peer/index.vue` |
| 22 | Address Book Names | `/address_book_collection` | `my/address_book/collection.vue` |
| 23 | Address Books | `/address_book` | `my/address_book/index.vue` |
| 24 | Tags | `/tag` | `my/tag/index.vue` |
| 25 | Shared Records | `/shareRecord` | `my/share_record/index.vue` |
| 26 | Login Log | `/loginLog` | `my/login_log/index.vue` |

### System (admin management)
| # | Page | Route | Component |
|---|---|---|---|
| 30 | Device Management | `/user/peer` | `peer/index.vue` |
| 31 | Group Management | `/user/group` | `group/index.vue` |
| 32 | Device Group Management | `/user/deviceGroup` | `group/deviceGroupList.vue` |
| 33 | User Management | `/user/index` (+ `add`/`edit`) | `user/index.vue`, `user/edit.vue` |
| 34 | Address Book Names (admin) | `/user/addressBookName` | `address_book/collection.vue` |
| 35 | Address Books (admin) | `/user/addressBook` | `address_book/index.vue` |
| 36 | Tags (admin) | `/user/tag` | `tag/index.vue` |
| 37 | **SSO / OAuth Providers** | `/oauth` | `oauth/index.vue` |
| 38 | API Tokens | `/userToken` | `user/token.vue` |
| 39 | Login Log (all users) | `/loginLog` | `login/log.vue` |
| 40 | Audit — Connections | `/auditConn` | `audit/connList.vue` |
| 41 | Audit — File Transfers | `/auditFile` | `audit/fileList.vue` |
| 42 | Shared Records (admin) | `/shareRecord` | `share_record/index.vue` |
| 43 | Server Commands | `/serverCmd` | `rustdesk/control.vue` |
</content>
