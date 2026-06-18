#!/usr/bin/env bash
# NextSession API server + web console (our hardened fork of rustdesk-api) via plain podman.
#
# Run AFTER deploy.sh (which starts hbbs/hbbr and generates the keypair). This adds the
# accounts / address book / device-groups / audit / OIDC web console, wired to the same
# rendezvous key. Builds from apiserver/ so the security hardening is included — NOT the
# upstream image. See SECURITY.md for the mandatory secrets + Entra OIDC wiring.
set -euo pipefail

PUBLIC_HOST="${PUBLIC_HOST:-nextsession.nxlink.com}"
NET="${NET:-nextsession}"
HBBS_VOL="${HBBS_VOL:-nextsession-hbbs-data}"     # from deploy.sh — holds id_ed25519.pub
API_DATA_VOL="${API_DATA_VOL:-nextsession-api-data}"
API_PORT="${API_PORT:-21114}"
BIND_ADDR="${BIND_ADDR:-127.0.0.1}"               # private bind; front with a TLS reverse proxy
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---- secrets (never bake into the image/config) ---------------------------
# jwt.key: required. Empty => login disabled; weak/shared => forgeable tokens (see SECURITY.md).
if ! podman secret exists nextsession-jwt 2>/dev/null; then
  echo ">> generating random jwt.key podman secret (nextsession-jwt)"
  head -c 48 /dev/urandom | base64 | tr -d '\n' | podman secret create nextsession-jwt -
fi

echo ">> reading rendezvous public key from hbbs volume"
RS_PUB_KEY="$(podman run --rm -v "${HBBS_VOL}:/k:ro,Z" docker.io/library/busybox cat /k/id_ed25519.pub 2>/dev/null | tr -d '\n')"
if [ -z "${RS_PUB_KEY}" ]; then
  echo "!! could not read id_ed25519.pub — run server/deploy.sh first" >&2; exit 1
fi

echo ">> building NextSession API image from our hardened fork (apiserver/)"
# The fork keeps the upstream build; produce the image it expects. If the build is heavy on
# this host, build in CI and set IMAGE=<registry>/nextsession-api to skip.
IMAGE="${IMAGE:-localhost/nextsession-api:latest}"
if [ "${IMAGE}" = "localhost/nextsession-api:latest" ]; then
  ( cd "${REPO_ROOT}/apiserver" && ./build.sh && podman build -t "${IMAGE}" . )
fi

podman volume exists "${API_DATA_VOL}" || podman volume create "${API_DATA_VOL}"

echo ">> starting nextsession-api on ${BIND_ADDR}:${API_PORT} (proxy 443 -> here)"
podman rm -f nextsession-api 2>/dev/null || true
podman run -d --name nextsession-api \
  --network "${NET}" \
  --restart unless-stopped \
  --secret nextsession-jwt,type=env,target=RUSTDESK_API_JWT_KEY \
  -e TZ=America/Chicago \
  -e RUSTDESK_API_LANG=en \
  -e RUSTDESK_API_RUSTDESK_ID_SERVER="${PUBLIC_HOST}:21116" \
  -e RUSTDESK_API_RUSTDESK_RELAY_SERVER="${PUBLIC_HOST}:21117" \
  -e RUSTDESK_API_RUSTDESK_API_SERVER="https://${PUBLIC_HOST}" \
  -e RUSTDESK_API_RUSTDESK_KEY="${RS_PUB_KEY}" \
  -e RUSTDESK_API_APP_REGISTER=false \
  -e RUSTDESK_API_APP_WEB_SSO=true \
  -e RUSTDESK_API_GIN_MODE=release \
  -e RUSTDESK_API_LDAP_ENABLE=false \
  -v "${API_DATA_VOL}:/app/data:Z" \
  -p "${BIND_ADDR}:${API_PORT}:21114" \
  "${IMAGE}"

echo ">> waiting for first-run admin password..."
sleep 4
echo "=========================================================================="
echo " Admin password (printed once — capture, then change on first login):"
podman logs nextsession-api 2>&1 | grep -i 'Admin Password' | tail -1 || \
  echo "  (check: podman logs nextsession-api | grep -i 'Admin Password')"
echo "=========================================================================="
cat <<NEXT

NEXT STEPS
  1. Reverse-proxy https://${PUBLIC_HOST}  ->  ${BIND_ADDR}:${API_PORT}  (TLS terminates at proxy).
  2. Web console: https://${PUBLIC_HOST}/_admin/   (login admin + printed password).
  3. Add Microsoft Entra OIDC in the console (Oauth providers):
       type: OIDC
       issuer: https://login.microsoftonline.com/<TENANT_ID>/v2.0
       client_id / client_secret: from the Entra app registration
       redirect: https://${PUBLIC_HOST}/api/oidc/callback   (register this in Entra)
       scopes: openid profile email
  4. Clients already point at the API via custom.txt (api-server=https://${PUBLIC_HOST}).
NEXT
