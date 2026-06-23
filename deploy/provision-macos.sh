#!/bin/bash
#
# provision-macos.sh — Unattended mass-deploy of the NextSession agent on macOS.
#
# Idempotent RMM/MDM-friendly provisioner. Installs the signed NextSession .pkg,
# starts the LaunchDaemon/LaunchAgent, sets a UNIQUE strong permanent password,
# forces password approve-mode, reads the device ID, and (optionally) registers
# the device into the shared RustDesk/NextSession address book via the admin API.
#
# Servers + key are baked into the signed custom.txt — this script NEVER sets servers.
#
# TCC WARNING: Screen Recording + Accessibility (and Input Monitoring) must be
# pre-granted via an MDM PPPC profile. Without it the agent will NOT work
# unattended. See deploy/macos-mdm-pppc.md.
#
# Exit codes: 0 success; non-zero on any failure.
#
# Usage:
#   sudo ./provision-macos.sh --pkg <path-or-URL-to-NextSession.pkg> [options]
#
# Options:
#   --pkg <path|url>        Path or http(s) URL to the NextSession .pkg (REQUIRED)
#   --app <path>            Installed app bundle path (default: /Applications/NextSession.app)
#   --record-dir <dir>      Where to write the {hostname,id,password} JSON + CSV
#                           (default: /var/log/nextsession-provision)
#   --no-register           Skip address-book registration even if a token is set
#   -h | --help             Show this help
#
# Environment (address-book registration; all optional — registration is skipped
# unless API_BASE + ADMIN_API_TOKEN + AB_USER_ID + AB_COLLECTION_ID are all set):
#   NS_API_BASE             API server base URL, e.g. https://rdp.example.com
#   NS_ADMIN_API_TOKEN      Admin service-account token (sent as 'api-token' header)
#   NS_AB_USER_ID           Owner user id of the shared collection (integer)
#   NS_AB_COLLECTION_ID     Target shared collection id (integer; 0 = owner default AB)
#   NS_AB_TAGS              Comma-separated tags, e.g. "site-a,rmm" (optional)
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults / constants
# ---------------------------------------------------------------------------
BUNDLE_ID="com.nxlink.nextsession"
APP_PATH="/Applications/NextSession.app"
PKG_SRC=""
RECORD_DIR="/var/log/nextsession-provision"
DO_REGISTER=1
LOG_FILE=""

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
ts() { date +"%Y-%m-%dT%H:%M:%S%z"; }
log()  { printf '%s [INFO]  %s\n'  "$(ts)" "$*" | tee -a "${LOG_FILE:-/dev/stderr}" >&2; }
warn() { printf '%s [WARN]  %s\n'  "$(ts)" "$*" | tee -a "${LOG_FILE:-/dev/stderr}" >&2; }
err()  { printf '%s [ERROR] %s\n'  "$(ts)" "$*" | tee -a "${LOG_FILE:-/dev/stderr}" >&2; }
die()  { err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
usage() { sed -n '2,40p' "$0"; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg)         PKG_SRC="${2:-}"; shift 2 ;;
    --app)         APP_PATH="${2:-}"; shift 2 ;;
    --record-dir)  RECORD_DIR="${2:-}"; shift 2 ;;
    --no-register) DO_REGISTER=0; shift ;;
    -h|--help)     usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
[[ "$(id -u)" -eq 0 ]]         || die "Must run as root (use sudo). TCC grants, pkg install, and the privileged CLI all require root."
[[ -n "$PKG_SRC" ]]            || die "--pkg <path-or-URL> is required."

mkdir -p "$RECORD_DIR" || die "Cannot create record dir: $RECORD_DIR"
chmod 700 "$RECORD_DIR" || true
LOG_FILE="$RECORD_DIR/provision-$(date +%Y%m%d-%H%M%S).log"
: > "$LOG_FILE" || die "Cannot write log file: $LOG_FILE"

log "NextSession macOS provisioning starting."
log "Log file: $LOG_FILE"
log "Record dir: $RECORD_DIR"

HOSTNAME_FQDN="$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || hostname)"
log "Host: $HOSTNAME_FQDN"

# ===========================================================================
# Step 1: Install the .pkg (idempotent) and ensure the LaunchDaemon/Agent.
# ===========================================================================
PKG_LOCAL="$PKG_SRC"
PKG_TMP=""
cleanup() { [[ -n "$PKG_TMP" && -f "$PKG_TMP" ]] && rm -f "$PKG_TMP" || true; }
trap cleanup EXIT

if [[ "$PKG_SRC" =~ ^https?:// ]]; then
  PKG_TMP="$(mktemp /tmp/nextsession.XXXXXX.pkg)"
  log "Downloading pkg from URL: $PKG_SRC"
  curl -fSL --retry 3 --retry-delay 5 -o "$PKG_TMP" "$PKG_SRC" \
    || die "Failed to download pkg from $PKG_SRC"
  PKG_LOCAL="$PKG_TMP"
fi
[[ -f "$PKG_LOCAL" ]] || die "pkg not found: $PKG_LOCAL"

# Idempotent install: installer is naturally idempotent (re-runs upgrade/overwrite).
# We install unconditionally so re-provisioning picks up a newer pkg; this is safe.
log "Installing pkg: $PKG_LOCAL"
if installer -verbose -pkg "$PKG_LOCAL" -target / >>"$LOG_FILE" 2>&1; then
  log "pkg install completed."
else
  die "installer failed. See $LOG_FILE"
fi

[[ -d "$APP_PATH" ]] || die "App bundle not present after install: $APP_PATH"
BIN="$APP_PATH/Contents/MacOS/nextsession"
[[ -x "$BIN" ]] || die "Agent binary not found/executable: $BIN"
log "Agent binary: $BIN"

# Ensure the service (LaunchDaemon _service.plist + LaunchAgent _server.plist) is
# installed and running. --install-service is idempotent: it re-registers/loads
# the daemon+agent. The pkg postinstall may already have done this; running it
# again is harmless and guarantees the service is up before we set the password.
DAEMON_PLIST="/Library/LaunchDaemons/${BUNDLE_ID}_service.plist"
AGENT_PLIST="/Library/LaunchAgents/${BUNDLE_ID}_server.plist"

log "Installing/starting NextSession service (LaunchDaemon + LaunchAgent)."
if "$BIN" --install-service >>"$LOG_FILE" 2>&1; then
  log "--install-service completed."
else
  warn "--install-service returned non-zero; checking whether daemon is already loaded."
fi

# Give launchd a moment, then verify the daemon is loaded.
ab_wait_for_service() {
  local i
  for i in $(seq 1 15); do
    if launchctl print "system/${BUNDLE_ID}_service" >/dev/null 2>&1; then
      return 0
    fi
    # Fallback: legacy launchctl list match.
    if launchctl list 2>/dev/null | grep -q "${BUNDLE_ID}_service"; then
      return 0
    fi
    sleep 1
  done
  return 1
}
if ab_wait_for_service; then
  log "LaunchDaemon is loaded: ${BUNDLE_ID}_service"
else
  warn "Could not confirm LaunchDaemon ${BUNDLE_ID}_service via launchctl."
  warn "Expected plist: $DAEMON_PLIST"
  # TODO(verify): exact launchctl service label may differ from the plist basename
  # on some macOS versions. Confirm the label printed by:
  #   launchctl print system/${BUNDLE_ID}_service
  # If different, adjust ab_wait_for_service accordingly.
  [[ -f "$DAEMON_PLIST" ]] || warn "LaunchDaemon plist missing at $DAEMON_PLIST — service may not survive reboot."
fi

# ===========================================================================
# Step 2: Generate a UNIQUE strong permanent password; set it; set approve-mode.
# ===========================================================================
# Strong, URL/CSV-safe permanent password (no shell-special chars, no commas/quotes).
gen_password() {
  # 24 chars from a safe alphabet using the kernel CSPRNG.
  LC_ALL=C tr -dc 'A-Za-z0-9_@%+=:.-' < /dev/urandom 2>/dev/null | head -c 24
}

# Marker file so we do NOT rotate the password on every RMM/MDM re-run. Rotating
# on re-run would desync the device password from the already-registered shared
# address-book entry (the AB 'create' endpoint rejects the duplicate, so the new
# password would never reach the AB) and break one-click connect. Mirrors the
# Linux script's PW_MARKER design. Root-only (dir is chmod 700 above).
PW_MARKER="$RECORD_DIR/password-set"

if [[ -f "$PW_MARKER" ]]; then
  log "Password already provisioned on this host (marker present); reusing stored value (no rotation)."
  PERM_PW="$(cat "$PW_MARKER")"
  [[ -n "$PERM_PW" ]] || die "Password marker present but empty: $PW_MARKER"
else
  PERM_PW="$(gen_password)"
  [[ ${#PERM_PW} -ge 20 ]] || die "Password generation failed (got '${#PERM_PW}' chars)."
  log "Generated a unique permanent password (24 chars). Value is NOT logged."

  # The privileged CLI talks to the running root service over IPC and writes to the
  # service's config (/var/root/Library/Preferences/NextSession/NextSession.toml).
  # Requires installed + root + service running (ensured above).
  log "Setting permanent password via verified command (--password)."
  if "$BIN" --password "$PERM_PW" >>"$LOG_FILE" 2>&1; then
    log "--password set (service reported success)."
  else
    die "Failed to set permanent password via --password. See $LOG_FILE"
  fi

  # Persist for idempotent re-runs. Root-only marker.
  ( umask 077; printf '%s' "$PERM_PW" > "$PW_MARKER" )
  chmod 600 "$PW_MARKER" || true
  log "Recorded password marker (root-only) for idempotent re-runs."
fi

# Force unattended approval semantics. These are no-ops if already baked into the
# signed custom.txt default/override settings, but we set them explicitly for
# determinism. approve-mode=password is the requirement.
log "Setting approve-mode=password."
"$BIN" --option approve-mode password >>"$LOG_FILE" 2>&1 \
  || die "Failed to set approve-mode=password. See $LOG_FILE"

log "Setting verification-method=use-permanent-password."
"$BIN" --option verification-method use-permanent-password >>"$LOG_FILE" 2>&1 \
  || warn "Failed to set verification-method (non-fatal; may be baked into custom.txt)."

# Best-effort read-back for audit (do not fail the run on read-back).
AM_READBACK="$("$BIN" --option approve-mode 2>/dev/null | tr -d '\r\n' || true)"
log "approve-mode read-back: '${AM_READBACK:-<unknown>}'"

# ===========================================================================
# Step 3: Read the device ID.
# ===========================================================================
get_device_id() {
  local i out
  for i in $(seq 1 15); do
    out="$("$BIN" --get-id 2>/dev/null | tr -d '\r\n ' || true)"
    if [[ "$out" =~ ^[0-9]{6,}$ ]]; then
      printf '%s' "$out"
      return 0
    fi
    sleep 1
  done
  return 1
}
log "Reading device ID (--get-id)."
DEVICE_ID="$(get_device_id || true)"
[[ -n "$DEVICE_ID" ]] || die "Could not read a numeric device ID via --get-id. See $LOG_FILE"
log "Device ID: $DEVICE_ID"

# ===========================================================================
# Step 4 (always): Emit {hostname,id,password} JSON record + append CSV.
# ===========================================================================
RECORD_JSON="$RECORD_DIR/${HOSTNAME_FQDN}-${DEVICE_ID}.json"
CSV_FILE="$RECORD_DIR/inventory.csv"

# JSON (contains the password — directory is chmod 700, file chmod 600).
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
{
  printf '{\n'
  printf '  "hostname": "%s",\n' "$(json_escape "$HOSTNAME_FQDN")"
  printf '  "id": "%s",\n'       "$(json_escape "$DEVICE_ID")"
  printf '  "password": "%s",\n' "$(json_escape "$PERM_PW")"
  printf '  "bundle_id": "%s",\n' "$BUNDLE_ID"
  printf '  "provisioned_at": "%s"\n' "$(ts)"
  printf '}\n'
} > "$RECORD_JSON"
chmod 600 "$RECORD_JSON" || true
log "Wrote record JSON: $RECORD_JSON"

# CSV (idempotent header; one row per provision). Password included for handoff to
# the RMM/CMDB ingestion — treat this file as a secret (chmod 600).
if [[ ! -f "$CSV_FILE" ]]; then
  printf 'hostname,id,password,bundle_id,provisioned_at\n' > "$CSV_FILE"
fi
printf '%s,%s,%s,%s,%s\n' \
  "$HOSTNAME_FQDN" "$DEVICE_ID" "$PERM_PW" "$BUNDLE_ID" "$(ts)" >> "$CSV_FILE"
chmod 600 "$CSV_FILE" || true
log "Appended inventory CSV: $CSV_FILE"

# ===========================================================================
# Step 3b/Step 4 (if supported): Register into the shared address book.
# ===========================================================================
# Registration is attempted only if all required env vars are present and not
# disabled by --no-register. The shared-AB password lives in the 'password' field
# (stored verbatim server-side). The endpoint is admin-only (api-token header).
NS_API_BASE="${NS_API_BASE:-}"
NS_ADMIN_API_TOKEN="${NS_ADMIN_API_TOKEN:-}"
NS_AB_USER_ID="${NS_AB_USER_ID:-}"
NS_AB_COLLECTION_ID="${NS_AB_COLLECTION_ID:-}"
NS_AB_TAGS="${NS_AB_TAGS:-}"

register_address_book() {
  local base="${NS_API_BASE%/}"
  local url="$base/api/admin/address_book/create"

  # Build tags JSON array from comma-separated NS_AB_TAGS.
  local tags_json="[]"
  if [[ -n "$NS_AB_TAGS" ]]; then
    local IFS=',' t parts=()
    read -r -a parts <<< "$NS_AB_TAGS"
    tags_json="["
    local first=1
    for t in "${parts[@]}"; do
      t="$(printf '%s' "$t" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [[ -z "$t" ]] && continue
      if [[ $first -eq 1 ]]; then first=0; else tags_json+=","; fi
      tags_json+="\"$(json_escape "$t")\""
    done
    tags_json+="]"
  fi

  # collection_id may be 0 (default AB); only require it to be set, allow "0".
  local payload
  payload="$(cat <<JSON
{
  "id": "$(json_escape "$DEVICE_ID")",
  "user_id": ${NS_AB_USER_ID},
  "collection_id": ${NS_AB_COLLECTION_ID},
  "alias": "$(json_escape "$HOSTNAME_FQDN")",
  "hostname": "$(json_escape "$HOSTNAME_FQDN")",
  "username": "admin",
  "platform": "Mac OS",
  "tags": ${tags_json},
  "password": "$(json_escape "$PERM_PW")",
  "hash": ""
}
JSON
)"

  log "Registering device into shared address book: $url"
  local http_code body resp
  resp="$(curl -sS -w $'\n%{http_code}' \
      -X POST "$url" \
      -H "api-token: ${NS_ADMIN_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$payload" 2>>"$LOG_FILE" || true)"
  http_code="$(printf '%s' "$resp" | tail -n1)"
  body="$(printf '%s' "$resp" | sed '$d')"

  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    log "Address-book registration succeeded (HTTP $http_code)."
    return 0
  fi

  # Treat duplicate-entry as success (idempotent re-provision).
  if printf '%s' "$body" | grep -qiE 'exist|duplicate|already'; then
    warn "Address-book entry appears to already exist (HTTP $http_code) — treating as idempotent success."
    log "Server body: $body"
    return 0
  fi

  warn "Address-book registration FAILED (HTTP $http_code). Body: $body"
  warn "Device is still provisioned locally; the {hostname,id,password} record + CSV"
  warn "in $RECORD_DIR are the fallback for RMM/CMDB ingestion."
  return 1
}

REGISTERED="no"
if [[ "$DO_REGISTER" -eq 1 ]]; then
  if [[ -n "$NS_API_BASE" && -n "$NS_ADMIN_API_TOKEN" && -n "$NS_AB_USER_ID" && -n "$NS_AB_COLLECTION_ID" ]]; then
    if register_address_book; then
      REGISTERED="yes"
    else
      REGISTERED="failed"
      # Non-fatal: the local record + CSV are the documented fallback path.
    fi
  else
    log "Address-book registration not configured (need NS_API_BASE, NS_ADMIN_API_TOKEN,"
    log "NS_AB_USER_ID, NS_AB_COLLECTION_ID). Emitted local record + CSV instead."
    REGISTERED="skipped"
  fi
else
  log "Address-book registration disabled via --no-register. Emitted local record + CSV."
  REGISTERED="disabled"
fi

# ===========================================================================
# Step 4 (WARN): TCC / PPPC requirements — the load-bearing manual gate.
# ===========================================================================
cat >&2 <<'WARNBLOCK'

================================================================================
  !!  ACTION REQUIRED: macOS TCC PERMISSIONS  !!
================================================================================
  The NextSession agent CANNOT operate unattended until these macOS TCC
  permissions are granted to com.nxlink.nextsession:

    * Screen Recording   (kTCCServiceScreenCapture)  -- view the screen
    * Accessibility      (Accessibility / PostEvent) -- control keyboard+mouse
    * Input Monitoring   (kTCCServiceListenEvent)    -- HID input

  These CANNOT be granted by this script, by sqlite, by tccutil, or by any
  root process. The ONLY unattended way to grant them is an MDM-delivered
  PPPC configuration profile pushed to a supervised/MDM-enrolled Mac.

  >> The RMM/MDM MUST deploy the PPPC profile BEFORE or WITH this agent. <<

  Without that PPPC profile the agent will NOT work unattended.

  See:  deploy/macos-mdm-pppc.md
        (which TCC services, the bundle id, and the code-requirement to use)

  NOTE: Screen Recording is the most fragile item — on older macOS versions or
  non-supervised devices it may still require a one-time human approval in
  System Settings > Privacy & Security. Validate on your target OS.
================================================================================

WARNBLOCK

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
log "PROVISION COMPLETE  host=$HOSTNAME_FQDN id=$DEVICE_ID approve-mode=${AM_READBACK:-password} register=$REGISTERED"
log "Local record: $RECORD_JSON"
log "Inventory CSV: $CSV_FILE"
log "Remember: grant TCC via PPPC (deploy/macos-mdm-pppc.md) or the agent is unusable unattended."

exit 0
