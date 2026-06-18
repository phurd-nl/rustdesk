#!/usr/bin/env bash
# NextSession self-hosted signal + relay (OSS hbbs/hbbr) via plain podman — no compose.
#
# Run this ON the NextSession server VM (the host nextsession.nxlink.com resolves to).
# It starts hbbr (relay) and hbbs (rendezvous/signal), persists the server keypair in a
# named volume, and prints the public key you paste into branding/custom_client.json.
#
# Pro upgrade later: swap the image/args and inject the license token as a podman secret
# (see SECRET NOTE at the bottom) — the client side (custom.txt) does not change.
set -euo pipefail

# ---- config ---------------------------------------------------------------
PUBLIC_HOST="${PUBLIC_HOST:-nextsession.nxlink.com}"   # what clients connect to
IMAGE="${IMAGE:-docker.io/rustdesk/rustdesk-server:latest}"
NET="${NET:-nextsession}"
DATA_VOL="${DATA_VOL:-nextsession-hbbs-data}"           # holds id_ed25519(.pub) + sqlite db
# ---------------------------------------------------------------------------

echo ">> network"
podman network exists "$NET" || podman network create "$NET"
podman volume exists "$DATA_VOL" || podman volume create "$DATA_VOL"

echo ">> hbbr (relay) — tcp 21117 (relay) + 21119 (websocket relay)"
podman rm -f nextsession-hbbr 2>/dev/null || true
podman run -d --name nextsession-hbbr \
  --network "$NET" \
  --restart unless-stopped \
  -p 21117:21117 \
  -p 21119:21119 \
  "$IMAGE" hbbr

echo ">> hbbs (signal) — tcp 21115/21116/21118 + udp 21116; -r points clients at our relay"
podman rm -f nextsession-hbbs 2>/dev/null || true
podman run -d --name nextsession-hbbs \
  --network "$NET" \
  --restart unless-stopped \
  -v "${DATA_VOL}:/root:Z" \
  -p 21115:21115 \
  -p 21116:21116 \
  -p 21116:21116/udp \
  -p 21118:21118 \
  "$IMAGE" hbbs -r "${PUBLIC_HOST}:21117"

echo ">> waiting for hbbs to generate its keypair..."
for _ in $(seq 1 20); do
  if podman exec nextsession-hbbs test -f /root/id_ed25519.pub 2>/dev/null; then break; fi
  sleep 1
done

echo
echo "=========================================================================="
echo " RS_PUB_KEY (paste into branding/custom_client.json -> override-settings.key):"
podman exec nextsession-hbbs cat /root/id_ed25519.pub || \
  echo "  (not ready yet — re-run: podman exec nextsession-hbbs cat /root/id_ed25519.pub)"
echo "=========================================================================="
echo
echo "Then on your build host:  python3 branding/make_custom.py  &&  rebuild clients."
echo
cat <<'PORTS'
Firewall / NAT — open to clients:
  21115/tcp  (hbbs: NAT type test)
  21116/tcp  (hbbs: ID registration / hole punching)
  21116/udp  (hbbs: heartbeat)
  21117/tcp  (hbbr: relay)
  21118/tcp  (hbbs: web client / websocket)   } only if you serve the web client
  21119/tcp  (hbbr: web relay / websocket)     }   (off-net access needs an explicit rule)

SECRET NOTE (for the future Pro license token, not needed for OSS):
  printf '%s' "<LICENSE_TOKEN>" | podman secret create nextsession-license -
  # then add to the relevant container:  --secret nextsession-license,type=env,target=KEY
PORTS
