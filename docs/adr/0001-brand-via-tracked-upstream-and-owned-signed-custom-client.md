# 0001 — Brand NextSession via tracked upstream and an owned signed custom-client channel

- **Status:** Accepted
- **Date:** 2026-06-18

## Context

`phurd-nl/rustdesk` is a fork of the actively-developed RustDesk (v1.4.8).
We want a NextLink-branded remote-support product, "NextSession", across
Windows, Linux, macOS, Android (and an iOS spike), pointing at our own
`nextsession.nxlink.com` rendezvous/relay servers.

RustDesk's brand-critical defaults (`APP_NAME`, `ORG`, `RENDEZVOUS_SERVERS`,
`RS_PUB_KEY`) live in `libs/hbb_common` — a submodule pointing at upstream
`rustdesk/hbb_common`. RustDesk also ships an official customization channel:
`load_custom_client()` reads a base64, **signed** `custom.txt` that overrides
app name, servers, public key, and default/override settings at startup. The
signature is verified in `src/common.rs` against a hardcoded public key
(`5Qbwsde3unUcJBtrx9ZkvUmwFNoExHzpryHuPUdqlWM=`) whose private half RustDesk
holds (their paid "custom client generator").

We need RustDesk's ongoing security/feature fixes, so divergence is a cost.

## Decision

1. **Track upstream.** Treat branding as a thin, overridable layer; keep the
   diff small so `git merge upstream` stays low-conflict. No hard fork.
2. **Own the custom-client channel (A1).** Replace the single hardcoded signing
   public key in `src/common.rs` with a NextLink-generated public key. Generate
   our own NaCl `sign` keypair; sign a NextSession `custom.txt` carrying
   `app-name=NextSession`, `org=com.nxlink`, the rendezvous/relay/api hosts
   (`nextsession.nxlink.com`), the rendezvous `RS_PUB_KEY`, and default theme/
   settings. Ship `custom.txt` with each installer. Extend `read_custom_client`
   with a small `org` handler so `ORG` is data-driven too.
3. **Do not fork the `hbb_common` submodule.** All runtime branding flows
   through the signed config, leaving the submodule pristine.
4. **Edge-only rename.** Keep the internal crate `rustdesk`/`librustdesk`
   (wired into flutter_rust_bridge, build.py, native entry points). Rename only
   the user-facing edge — produced binary/app/installer filenames, shortcuts,
   service name, bundle ID `com.nxlink.nextsession` — via packaging.

## Consequences

- Re-branding or re-pointing servers becomes "regenerate and re-sign a
  `custom.txt`", not a recompile of patched constants.
- The source tree still reads `rustdesk` in crate/identifier positions; a future
  reader must know branding is intentionally confined to `custom.txt`, assets,
  and packaging. (This ADR is that context.)
- We hold a private signing key that must be safeguarded (podman secret / vault);
  losing it means re-issuing clients. It is distinct from the rendezvous
  `RS_PUB_KEY`.
- Merges from upstream touch few branded files: `src/common.rs` (one key + the
  org handler), packaging configs, and asset files. Conflicts are bounded.

## Alternatives considered

- **A2 — patch submodule defaults.** Fork `rustdesk/hbb_common`, re-point the
  submodule, edit `RENDEZVOUS_SERVERS`/`RS_PUB_KEY`/`APP_NAME`/`ORG`. Rejected:
  adds a second submodule to maintain and merge, and bakes branding into
  compiled constants instead of swappable data.
- **Hard fork + global rename.** Cleaner-looking tree, but every upstream merge
  becomes a conflict storm and we inherit backporting RustDesk's CVE fixes
  ourselves. Rejected for a small team.
- **Pay RustDesk for a custom client.** Uses their signing key, no source
  change — but recurring cost, less control, and doesn't cover self-host server
  branding. Rejected.
