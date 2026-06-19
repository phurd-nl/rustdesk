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
# copy dist/* into apiserver/resources/admin/ (router.go StaticFS serves it at /_admin/;
# resources/web is the Flutter web *client*, a different thing)
```

Done on the console: NextSession logo (login + register + header), favicon,
English-default locale + "NextSession Admin" title, full Ticketing palette in
**both** light and dark, frosted-glass surfaces (cards/dialogs/drawers) and the
radial gradient background washes. Built (`npm run build`) and deployed into
`apiserver/resources/admin/`. Remaining: a manual spacing/screenshot pass once
it's running on the VM.

### Brand marks & auth screens (NextVault family)
The app icon and wordmark follow the **NextVault sibling identity**: orange-gradient
disc + folded white **N** badge, and a `NEXT`(orange `#f49e1b`) + `SESSION`(gray
`#8a8d90`, italic) lockup. Source icon `branding/assets/nextsession-icon.svg`;
wordmark `apiserver-web/src/assets/wordmark.png` (badge + Liberation Sans Bold/
BoldItalic — regenerate via `branding/render_assets.py make_wordmark`).

The console **login + register** screens are a deliberate dark brand moment that
mirrors the NextVault login: canvas `#0b1622`, frosted card `#16212e`, centered
wordmark, **orange** primary action (`#f49e1b`, overrides the app's blue here
only), and footer "NextSession Web · secured by Nextlink". The signed-in app
chrome stays UniFi-light/Ticketing (above) — light app, branded dark auth.

### Client (Flutter)
Brand color + dark theme ship via `custom.txt` (`theme: dark`, orange accent).
A deeper client restyle toward the UniFi-light palette is optional and large —
deferred; the icon/wordmark/About are already branded.

## Honest status
The theme is written, built (Node 22 via nvm *is* on the dev box), and the
`dist/` is deployed into `apiserver/resources/admin/`. Verified the tokens
(primary `#0559c9`, frosted `backdrop-filter`, dark `#11141a`/`#2b8bff`)
compiled into the CSS bundle. Not yet done: a live screenshot pass to tune
spacing — do that once the API server is running on the VM.
