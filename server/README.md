# NextSession server (self-hosted hbbs/hbbr)

Runs the OSS RustDesk signal + relay servers under NextLink control, via plain
`podman` (no compose), on the host `nextsession.nxlink.com`.

## Bring-up

```bash
# on the server VM:
sudo ./server/deploy.sh          # or: PUBLIC_HOST=nextsession.nxlink.com ./server/deploy.sh
```

It creates a podman network + data volume, starts `nextsession-hbbr` and
`nextsession-hbbs`, then prints the **RS_PUB_KEY**.

## Wire the key into clients

1. Copy the printed public key.
2. On the build host: set `override-settings.key` in
   `branding/custom_client.json` to that value.
3. `python3 branding/make_custom.py` → rebuild clients.

The server keypair lives in the `nextsession-hbbs-data` volume — **back it up**;
regenerating it invalidates every deployed client's pinned key.

## Ports

`21115/tcp`, `21116/tcp+udp`, `21117/tcp` are required. `21118`/`21119` (tcp)
are only for the web client and need an explicit off-net rule.

## Later: Pro

Swap the image/args and inject the license token as a podman secret (see the
SECRET NOTE in `deploy.sh`). The client `custom.txt` does not change.
