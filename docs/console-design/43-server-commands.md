# Server Commands
Route `/serverCmd` · `src/views/rustdesk/control.vue` · Audience: System (admin-only)

## Purpose
Send live administrative commands to the running hbbs (ID) and hbbr (RELAY) servers, and manage a library of reusable commands. This is the low-level operator console for the relay/rendezvous backend.

## Layout & content
Top→bottom:

1. **Header / status strip**
   - Intro line with a link to the command WIKI (`ServerCmdTips`).
   - **ID Status** badge — `Available` (success) / `Not available` (danger) + `Refresh`.
   - **RELAY Status** badge — `Available` / `Not available` + `Refresh`.
2. **Tabs** (card style): **Simple** and **Advanced**.

**Simple tab** — a wrapped row of action cards, each disabled unless its target server is reachable:
   - **RELAY_SERVERS** (`relay_servers.vue`) — text input of relay addresses; `Refresh` / `Save`. Targets ID server.
   - **ALWAYS_USE_RELAY** (`always_use_relay.vue`) — toggle; `Refresh` / `Save`. On save, also re-saves relay servers.
   - **MUST_LOGIN** (`must_login.vue`) — switch Y/N; `Refresh` / `Save`. Only enabled if the ID server advertises `must-login` support.
   - **USAGE** (`usage.vue`) — read-only table (IP, TIME, TOTAL, HIGHEST, AVG, SPEED); `Refresh`. Targets RELAY.
   - **BLOCKLIST** (`blocklist.vue`) — list with `Refresh` / `Add` / `Delete` (dialog). Targets RELAY.
   - **BLACKLIST** (`blacklist.vue`) — same shape as blocklist. Targets RELAY.

**Advanced tab**
   - **Toolbar** — `Filter`, `Add`, `Send To Id` (disabled unless ID reachable), `Send To Relay` (disabled unless RELAY reachable).
   - **Command library table** — columns: `cmd`, `alias`, `option`, `explain`, `actions` (`Send`, and for saved rows `Edit` / `Delete`).
   - **Add/Edit dialog** — fields: `cmd`, `alias`, `option`, `target` (radio: id_server `21115` / relay_server `21117`), `explain`; `Submit` / `Cancel`.
   - **Send dialog** (`SendCmd`) — `cmd`, `option` (with an Example hint), `Send` button, and a read-only multi-line `Result` textarea. The whole form disables if the target server is unreachable.

## How it works
- On mount, `checkCanSendIdServerCmd` / `checkCanSendRelayServerCmd` send a help command (`cmd:'h'`) to each target; success sets the Available flag. The ID help output is parsed to detect `must-login` support (`canControlMustLogin`).
- `canSendCmd(target)` gates every send button against the right server's availability.
- Library: `getList` loads saved commands; `toAdd`/`toUpdate` open the dialog; `submit` calls `create`/`update` (requires `cmd`); `del` confirms then `remove`.
- `showCmd(row)` opens the send dialog pre-filled with the row's cmd/target and an `Example`; `submitCmd` calls `sendCmd` and writes the raw response into `Result`.
- Simple-tab cards each fetch their own state on `Refresh` and persist on `Save` via `sendCmd`.

## States
- **Server unreachable:** status badge danger; all send buttons / forms for that target disabled. This is the dominant "error" state.
- **Empty:** library table stock "No Data".
- **Loading:** each simple card has its own `v-loading`; the library table has a spinner.
- **No-permission:** admin-only route.

## Design direction
- Light canvas; white cards, 14px radius, soft shadow; system-UI font.
- **Status strip** is the anchor: render ID and RELAY as two status chips with dot+label (Available = success `#27a35a`, Unavailable = danger `#f03a3a`) and an inline refresh; make unavailability obvious since it disables everything.
- Replace the all-caps stock card titles (RELAY_SERVERS, MUST_LOGIN…) with sentence-case names. Lay Simple-tab cards out as a responsive grid of equal cards.
- The **Send dialog Result** is operator output — use a monospace, dark-on-light code block with a copy button; show example as muted helper text.
- This is a power-user/destructive surface — keep `Send`/`Save` primary blue `#0559c9`, `Delete` danger, and add a clear "this affects the live server" affordance. PKCE-style guardrails not needed but confirm on destructive list edits.
- Keep the WIKI link as a quiet inline link, not a button.

## Copy
- Page title: "Server commands" (replace "ServerCmd")
- Status: "ID server", "Relay server"; badges "Available" / "Unavailable"; "Refresh"
- Tabs: "Quick settings" (replace "Simple"), "Advanced"
- Simple cards: "Relay servers", "Always use relay", "Require sign-in" (replace "Must login"), "Relay usage", "Block list", "Blacklist"
- Card buttons: "Refresh", "Save", "Add", "Delete"
- Advanced toolbar: "Filter", "Add command", "Send to ID server", "Send to relay server"
- Library columns: "Command", "Alias", "Option", "Description", "Actions"
- Library actions: "Send", "Edit", "Delete"
- Dialogs: field labels "Command", "Alias", "Option", "Target", "Description"; "Submit", "Cancel"
- Send dialog: title "Send command"; "Command", "Option", "Send", "Result"; example prefix "Example:"
