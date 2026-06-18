# NextSession Branding & Build Guide

NextSession is NextLink's remote-support product, forked from RustDesk and
**tracking upstream**. Branding is a thin, overridable layer so we can keep
merging RustDesk's security/feature updates. See `docs/adr/0001-*` for the why
and `CONTEXT.md` for the glossary.

## How branding is applied (the model)

Three independent channels — only edit the layer you mean to change:

| Channel | Carries | Where |
|---|---|---|
| **Signed `custom.txt`** | app name, reverse-DNS org, rendezvous/relay/api servers, RS_PUB_KEY, default settings | data blob, read at startup by `load_custom_client()` |
| **Visual assets** | icons, tray, logos, splash | files under `res/`, `flutter/**` |
| **Packaging** | binary/app/installer filenames, bundle IDs | `build.py`, platform runner configs |

The crate stays `rustdesk`/`librustdesk` internally (loaded by name in
`flutter/windows/runner/main.cpp`); only the **user-facing edge** is renamed.

## The custom-client channel (the core mechanism)

`custom.txt` is a base64, ed25519-signed JSON blob. The client verifies it
against the public key in the `KEY` constant in `src/common.rs` (set to
NextSession's key `SPmhyMs6+EV5yDULj7/3Hqq1YFgpEZa+HIU3L5TJh54=`). We hold the
matching private seed, so **NextLink owns the channel** — RustDesk's key no
longer works and ours does.

`src/common.rs` `read_custom_client()` applies: top-level `app-name` and `org`
(the `org` handler is our ~5-line addition), plus `override-settings` /
`default-settings` maps (server endpoints, RS_PUB_KEY via `key`, theme, …).

### Regenerate custom.txt (run whenever servers/key/name change)

```bash
# one-time: keypair (private seed is gitignored — back it up in a vault / podman secret)
python3 branding/gen_keys.py            # prints the public key for src/common.rs KEY
# edit branding/custom_client.json (set the real RS_PUB_KEY after hbbs keygen), then:
python3 branding/make_custom.py         # writes & round-trip-verifies custom.txt
```

`custom.txt` IS committed (it's public — it ships in every installer). The
private seed in `branding/secrets/` is **never** committed.

> **Rotating the signing key** also requires updating `KEY` in `src/common.rs`
> and the test fixture in its `tests` module (`NEXTSESSION_CUSTOM_FIXTURE`).

## Verifying the code change (on the build VM)

The native codec deps (libvpx/opus/aom/libyuv via vcpkg) aren't on the dev box,
so run the unit test where the toolchain lives:

```bash
cargo test --lib read_custom_client          # or: cargo test test_nextsession_custom_client
```

This exercises the real sodiumoxide verifier against our signed fixture and
asserts `APP_NAME=NextSession`, `ORG=com.nxlink`, and the server override.

## Assets

Masters: `branding/assets/nextsession-icon.svg` (disc + N) and
`nextsession-glyph.svg` (N only). Regenerate every raster from them:

```bash
/tmp/brandvenv/bin/python branding/render_assets.py      # needs cairosvg + pillow
```

Writes Windows `.ico`s, `res/*` PNGs/SVGs, the in-app logo, Android adaptive
mipmaps + status icon, iOS app-icon set, mac template-tray icons, the wordmark
lockup, and a macOS `.iconset`.

- **macOS `.icns`:** `iconutil -c icns branding/assets/nextsession.iconset` →
  copy to `flutter/macos/Runner/AppIcon.icns` (PIL can't write `.icns`).
- **Wordmark font:** v1 uses Liberation Sans Bold. Drop NextLink's real brand
  font in `~/.fonts` and re-run `render_assets.py` for the final lockup.

## UI strings & URLs

- **"RustDesk" in UI text auto-rebrands.** `src/lang.rs` `translate()` does
  `s.replace("RustDesk", &app_name)` whenever the app name isn't "RustDesk" — so
  the ~1100 "RustDesk" strings across `src/lang/*.rs` render as "NextSession" at
  runtime via `custom.txt`. Do NOT mass-edit lang files. Only literals that
  bypass `translate()` need manual fixing (done: tab title, 2FA issuer, CLI
  about/author).
- **URLs** point at `nextsession.nxlink.com`; the in-app RustDesk `/docs/` help
  links were removed (Flutter cards + sciter lang values blanked). Left alone on
  purpose: `is_public()` / `is_custom_client()` checks that compare against
  `"RustDesk"` / `rustdesk.com` — those are functional server-detection logic.

## Packaging rename — VM checklist (build-test each platform)

Done already (zero-risk display metadata): Windows `Runner.rc` VERSIONINFO,
`main.cpp` window-title fallback, `res/rustdesk.desktop` display fields,
`Cargo.toml` description/authors, `flutter/pubspec.yaml` description.

### APPLIED in-tree (just build-verify — these are untested without a toolchain)
- **Windows:** `flutter/windows/CMakeLists.txt` `BINARY_NAME`/`project()` →
  `nextsession`; `build.py:450` flutter exe path → `nextsession.exe`. (`librustdesk.dll`
  kept — loaded by name in `main.cpp`.)
- **macOS:** `AppInfo.xcconfig` `PRODUCT_NAME` → `NextSession`; bundle ids in
  `AppInfo.xcconfig` + `project.pbxproj` → `com.nxlink.nextsession`; `build.py`
  flutter-dmg refs `RustDesk.app`/`rustdesk.dmg` → `NextSession.app`/`nextsession.dmg`.
- **Android:** `build.gradle` `applicationId` → `com.nxlink.nextsession`;
  `AndroidManifest.xml` labels → `NextSession`. (Kotlin package `com.carriez.flutter_hbb`
  kept — code-level; verify a custom-permission build doesn't assume id==package.)

### STILL TODO — Linux (Slice 2), rename together or not at all
`build.py` deb section + `res/` files form one set: `/usr/share/rustdesk`,
`/etc/rustdesk`, `rustdesk.service`, `rustdesk.desktop`, `rustdesk-link.desktop`,
`pam.d/rustdesk`, the hicolor `rustdesk.png`/`rustdesk.svg`, and the desktop
`Exec=`/`Icon=`/`StartupWMClass=` fields. Deferred: low user value (paths are
invisible), high coupling. Rename all to `nextsession` in lockstep when done.
Also not renamed by design: the cargo binary `rustdesk` and the sciter/cargo-bundle
build paths in `build.py` (the Flutter build is primary).

### iOS (Slice 5 — spike only)
Controller-only is the likely ceiling (Apple blocks unattended capture/input;
App Store distribution of an AGPL remote-control fork is fraught). Confirm scope
before investing. Bundle id / `CFBundleDisplayName` in the iOS runner.

## Server side (run on the VM you're building)

Fresh hbbs + hbbr via **podman** (not compose) on `nextsession.nxlink.com`:

1. Run hbbr (relay) and hbbs (signal). hbbs generates `id_ed25519` /
   `id_ed25519.pub` on first start (its data dir).
2. Read `id_ed25519.pub` — that base64 string is the **RS_PUB_KEY**.
3. Put it in `branding/custom_client.json` → `override-settings.key`, re-run
   `make_custom.py`, rebuild clients.
4. Ports: 21115–21119/tcp + 21116/udp. License token (if/when Pro) → podman secret.

DNS: `nextsession.nxlink.com` A-record → the podman host.
