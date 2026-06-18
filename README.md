<p align="center">
  <img src="./res/nextsession-logo.png" alt="NextSession" height="72">
</p>

<h3 align="center">NextSession — NextLink Remote Support</h3>

NextSession is NextLink's branded remote-support application. It lets a
technician securely view and control a customer's device to provide support.
Clients connect through NextLink-operated infrastructure at
`nextsession.nxlink.com`.

NextSession is a downstream fork of [RustDesk](https://github.com/rustdesk/rustdesk)
and tracks it for upstream security and feature updates. Branding (name,
servers, signing key, icons) is layered on top so those merges stay clean.

## Platforms

Windows, Linux, and macOS desktops and Android are the supported targets.
iOS is under evaluation (controller-only is the likely ceiling — see
`BRANDING.md`). Slice order: Windows → Linux → macOS → Android → iOS spike.

## How it's customized

| Layer | What | Reference |
|---|---|---|
| Signed `custom.txt` | app name, org, servers, public key, defaults | `branding/`, `BRANDING.md` |
| Visual assets | icons, tray, logo, splash | `branding/assets/`, `res/`, `flutter/**` |
| Packaging | binary/app/installer names, bundle IDs | `build.py`, runner configs |

The internal crate stays `rustdesk`/`librustdesk`; only the user-facing edge is
renamed to NextSession. See **`BRANDING.md`** for the build, asset, and server
setup, and **`docs/adr/0001-*`** for the architecture decision.

## Quick start (maintainers)

```bash
git submodule update --init libs/hbb_common
python3 branding/gen_keys.py          # one-time signing keypair (back up the private seed!)
python3 branding/make_custom.py       # build + sign custom.txt
/tmp/brandvenv/bin/python branding/render_assets.py   # regenerate brand assets
```

Build instructions follow upstream RustDesk; the NextSession-specific build
deltas are in `BRANDING.md`.

## License & attribution

NextSession is built on **RustDesk**, which is licensed under the
**GNU AGPL-3.0**. NextSession is therefore also distributed under AGPL-3.0 — the
full text is in [`LICENCE`](./LICENCE). Per AGPL, the complete corresponding
source for any distributed or network-served build must remain available; this
repository satisfies that.

Original RustDesk project: https://github.com/rustdesk/rustdesk — © RustDesk /
Purslane Ltd and contributors. NextSession adds NextLink branding and
configuration; it is not affiliated with or endorsed by the RustDesk project.
