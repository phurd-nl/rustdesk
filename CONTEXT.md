# NextSession — Context & Glossary

NextSession is a NextLink-branded remote-support product, forked from RustDesk.
It tracks upstream RustDesk and layers branding as a thin, overridable layer
(see `docs/adr/`).

## Glossary

- **NextSession** — the product name. Replaces "RustDesk" as the user-facing
  brand (window titles, app name, installers, About). The internal Cargo crate
  may remain `rustdesk`/`librustdesk` to keep upstream merges clean.

- **Rendezvous server (signal server / hbbs)** — the server clients register
  with and use to discover/connect to peers. Upstream default is RustDesk's
  public `rs-ny.rustdesk.com`; NextSession points at NextLink-operated infra.

- **Relay server (hbbr)** — relays the session stream when a direct P2P
  connection can't be established. Operated alongside hbbs.

- **API server** — optional HTTP service for accounts, address book, logging
  (RustDesk Pro / self-host server-side). Configured alongside the others.

- **Public key (RS_PUB_KEY)** — the rendezvous server's public key, baked into
  the client so it can authenticate the server. MUST match the private key
  generated on the NextLink hbbs server. Coupling: change the server → change
  this value in the client.

- **Custom client config (`custom.txt`)** — RustDesk's official customization
  channel: a base64, signed JSON blob read at startup that overrides app name,
  rendezvous/relay/api servers, public key, and default/override settings.
  Verified against a hardcoded signing public key. NextSession replaces that
  signing key with its own, so NextLink controls the channel.

- **Custom-client signing key** — the keypair whose public half is compiled
  into the client and whose private half signs `custom.txt`. Distinct from the
  rendezvous server's RS_PUB_KEY. Upstream holds RustDesk's; NextSession holds
  its own.

- **Tracking upstream** — pulling RustDesk's security/feature updates via merge.
  Branding is deliberately confined to a few files so merges stay low-conflict.
