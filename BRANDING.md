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

## Packaging rename — VM checklist (build-test each platform)

Done already (zero-risk display metadata): Windows `Runner.rc` VERSIONINFO,
`main.cpp` window-title fallback, `res/rustdesk.desktop` display fields,
`Cargo.toml` description/authors, `flutter/pubspec.yaml` description.

Remaining renames are coupled to the build and MUST be verified by compiling:

### Windows (Slice 1)
- `flutter/windows/CMakeLists.txt`: `set(BINARY_NAME "rustdesk")` → `"nextsession"`
  and `project(rustdesk …)` → `project(nextsession …)`.
- `build.py`: `hbb_name = 'rustdesk'` → `'nextsession'`; the portable-installer
  step (`generate.py … -e …/rustdesk.exe`) → `nextsession.exe`. Grep `build.py`
  for `rustdesk.exe` and the Windows installer/AppName/Publisher strings.
- Keep `librustdesk.dll` as-is (loaded by name in `main.cpp`).

### Linux (Slice 2) — rename together or not at all
`build.py` deb section + `res/` files form one set: `/usr/share/rustdesk`,
`/etc/rustdesk`, `rustdesk.service`, `rustdesk.desktop`, `rustdesk-link.desktop`,
`pam.d/rustdesk`, the hicolor `rustdesk.png`/`rustdesk.svg`, and the desktop
`Exec=`/`Icon=`/`StartupWMClass=` fields. Rename all to `nextsession` in lockstep.

### macOS (Slice 3)
`build.py` create-dmg block: `RustDesk.app` → `NextSession.app`, volname, dmg
name. Bundle id `com.carriez.*` → `com.nxlink.nextsession` in the macOS runner.

### Android (Slice 4)
`flutter/android/app/build.gradle` `applicationId` → `com.nxlink.nextsession`;
`AndroidManifest.xml` `android:label`. Assets already regenerated.

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
