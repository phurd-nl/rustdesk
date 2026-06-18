# NextSession — Visual Design

NextSession matches the **NextLink "Ticketing" app** look: a **UniFi-inspired**
system — clean, light, blue-forward — with NextLink orange demoted to a subtle
accent. The orange **N** badge family mark (NextVault sibling) stays as the app
icon; the *interface chrome* follows the UniFi/Ticketing palette.

## Tokens (source of truth: Ticketing `frontend/src/index.css`)

| Token | Value | Use |
|---|---|---|
| primary | `#0559c9` (UniFi blue) | buttons, links, active states |
| background | `#f6f8fa` | app canvas |
| card / popover | `#ffffff` | surfaces |
| foreground | `#1b1f24` | primary text |
| muted-foreground | `#646e78` | secondary text |
| accent wash | `#e6f0ff` | hover/active background |
| border | `rgba(17,24,39,0.07)` | soft translucent lines |
| success | `#27a35a` · warning `#f5a623` (NextLink orange) · danger `#f03a3a` |
| radius | `0.5rem` (8px) | corners |
| sidebar | white rail, `#eef4ff` active pill, `#0559c9` active text |

## Where it's applied

### Web console (techs) — `apiserver-web/` (Vue 3 + Element Plus)
Our fork `phurd-nl/rustdesk-api-web`, branch `nextsession-theme`. The tokens are
mapped onto Element Plus CSS variables in `src/styles/nextsession-theme.scss`
(imported last in `main.js`). Build and deploy:

```bash
cd apiserver-web && npm i && npm run build      # vite -> dist/
# copy dist/* over apiserver/resources/web/ (served by the API at /_admin/)
```

Still to do on the console (next slice, build-verified on the VM): NextSession
logo on the login page + sidebar header, favicon, English default copy, and a
pass over dialogs/tables for spacing once it's running.

### Client (Flutter)
Brand color + dark theme ship via `custom.txt` (`theme: dark`, orange accent).
A deeper client restyle toward the UniFi-light palette is optional and large —
deferred; the icon/wordmark/About are already branded.

## Honest status
The theme override is written and committed to the fork; **the visual result
requires the vite build** (no Node toolchain on the dev box). Build it on the
VM/CI, drop `dist/` into `apiserver/resources/web`, and screenshot to iterate.
