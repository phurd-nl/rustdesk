#!/usr/bin/env bash
#
# provision-linux.sh — NextSession agent mass-provisioning for Linux endpoints.
#
# Designed to be pushed by an RMM to ~1000 Debian/Ubuntu endpoints. Idempotent:
# re-running it on an already-provisioned host is safe and converges to the same
# desired state (installed, enabled, running, password set, approve-mode=password,
# registered in the shared address book).
#
# WHAT IT DOES (idempotently):
#   1. Installs the nextsession .deb (from a local path or a URL) if not present.
#   2. Ensures the systemd service is enabled + running.
#   3. Generates a UNIQUE strong random permanent password and sets it via the
#      verified CLI (`nextsession --password`), run as root (the service user).
#   4. Sets approve-mode=password (and verification-method=use-permanent-password).
#   5. Reads the device ID (`nextsession --get-id`).
#   6. Registers {id, hostname, alias, tags, password} into the SHARED address book
#      via the admin API using a service-account token from an env var — IF a token
#      and collection id are provided. Otherwise emits the record to stdout and a
#      CSV for RMM collection. The token is NEVER hardcoded.
#
# SERVERS/KEY are baked into the signed binary via custom.txt — this script does
# NOT set servers, rendezvous, relay, or key.
#
# Exit codes: 0 = success, non-zero = a step failed (see logs).
#
# -----------------------------------------------------------------------------
# Verified facts this script relies on (see CLIENT/ADDRESS-BOOK findings):
#   - Binary:  /usr/bin/nextsession      Service: nextsession.service (User=root)
#   - Install service: `nextsession --install-service` (enables + starts).
#   - Set password:    `nextsession --password <PW>`  (prints "Done!").
#   - Set option:      `nextsession --option <key> <value>`; read: `--option <key>`.
#   - Get id:          `nextsession --get-id`  (numeric id; service must be up).
#   - All privileged CLI calls require: installed + root + running service.
#   - Admin AB endpoint: POST <api>/api/admin/address_book/create
#       header: api-token: <svc admin token>
#       body:   { id, user_id, collection_id, alias, hostname, username,
#                 platform, tags[], password, hash:"" }
#       (server stores password verbatim; shared-AB password lives in `password`.)
# -----------------------------------------------------------------------------

set -euo pipefail

# =============================================================================
# Configuration (override via environment; sensible defaults baked in)
# =============================================================================

# Path to a local .deb, OR a URL to download. If DEB_PATH points at an existing
# file it is used directly; otherwise if it looks like a URL it is downloaded.
# You may also pass a glob like /opt/rmm/nextsession-*.deb.
DEB_PATH="${NS_DEB_PATH:-${1:-/opt/rmm/nextsession-*.deb}}"
DEB_URL="${NS_DEB_URL:-}"            # optional: download source if no local file

# API base URL for address-book registration.
API_BASE="${NS_API_BASE:-https://nextsession.nxlink.com}"

# Service-account ADMIN api-token. MUST come from the environment (never hardcode).
# If empty, the script skips API registration and falls back to CSV/stdout.
API_TOKEN="${NS_API_TOKEN:-}"

# Shared address-book target. Both are required for API registration.
#   AB_USER_ID       = the service account user id that OWNS the shared collection
#   AB_COLLECTION_ID = the shared collection id (0 = that user's default/personal AB)
AB_USER_ID="${NS_AB_USER_ID:-}"
AB_COLLECTION_ID="${NS_AB_COLLECTION_ID:-}"

# Comma-separated tags to attach to the AB entry, e.g. "site-a,rmm,linux".
TAGS="${NS_TAGS:-rmm,linux}"

# Where to write the per-host record CSV for RMM collection.
CSV_OUT="${NS_CSV_OUT:-/var/log/nextsession-provision.csv}"

# Binary location (rename-aware).
NS_BIN="${NS_BIN:-/usr/bin/nextsession}"
SERVICE="${NS_SERVICE:-nextsession.service}"
DEB_PKG_NAME="${NS_DEB_PKG_NAME:-nextsession}"  # dpkg package name for status checks

# curl timeouts/retries for API + downloads.
CURL_CONNECT_TIMEOUT="${NS_CURL_CONNECT_TIMEOUT:-10}"
CURL_MAX_TIME="${NS_CURL_MAX_TIME:-60}"
CURL_RETRIES="${NS_CURL_RETRIES:-3}"

# Marker file so we don't regenerate/rotate the password on every RMM re-run.
STATE_DIR="${NS_STATE_DIR:-/var/lib/nextsession-provision}"
PW_MARKER="${STATE_DIR}/password-set"

# =============================================================================
# Logging helpers
# =============================================================================

log()  { printf '%s [provision-linux] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
warn() { log "WARN: $*"; }
die()  { log "FATAL: $*"; exit 1; }

# Redact a secret in any string we might log.
redact() { sed -e 's/[^ ]*/<redacted>/g'; }

# =============================================================================
# Preflight
# =============================================================================

[ "$(id -u)" -eq 0 ] || die "must run as root (service runs as root; privileged CLI requires root)."

command -v systemctl >/dev/null 2>&1 || die "systemctl not found; this script targets systemd hosts."
command -v dpkg      >/dev/null 2>&1 || die "dpkg not found; this script targets Debian/Ubuntu hosts."

# curl is required only for downloads and API registration; check lazily where used.
HAVE_CURL=0
command -v curl >/dev/null 2>&1 && HAVE_CURL=1

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"

# =============================================================================
# Step 1: Install the .deb (idempotent)
# =============================================================================

resolve_deb() {
    # Resolve DEB_PATH (which may be a glob) to a real file, or download DEB_URL.
    local candidate=""

    # Expand a glob if present (nullglob-ish: only keep if it matched a real file).
    # shellcheck disable=SC2086
    for f in $DEB_PATH; do
        if [ -f "$f" ]; then candidate="$f"; break; fi
    done

    if [ -n "$candidate" ]; then
        printf '%s' "$candidate"
        return 0
    fi

    # No local file. Try URL download if provided (or if DEB_PATH itself is a URL).
    local url="$DEB_URL"
    case "$DEB_PATH" in
        http://*|https://*) url="$DEB_PATH" ;;
    esac

    if [ -n "$url" ]; then
        [ "$HAVE_CURL" -eq 1 ] || die "curl required to download .deb from URL but not installed."
        local dest="${STATE_DIR}/nextsession-download.deb"
        log "Downloading .deb from URL ..."
        if ! curl -fsSL \
                --connect-timeout "$CURL_CONNECT_TIMEOUT" \
                --max-time "$CURL_MAX_TIME" \
                --retry "$CURL_RETRIES" --retry-delay 2 \
                -o "$dest" "$url"; then
            die "failed to download .deb from URL."
        fi
        printf '%s' "$dest"
        return 0
    fi

    return 1
}

install_deb() {
    if dpkg -s "$DEB_PKG_NAME" >/dev/null 2>&1; then
        local ver
        ver="$(dpkg-query -W -f='${Version}' "$DEB_PKG_NAME" 2>/dev/null || echo '?')"
        log "Package '$DEB_PKG_NAME' already installed (version $ver); skipping install."
        # NOTE: this script does not auto-upgrade. To force an upgrade, uninstall
        # first or extend this with a version comparison. (Intentional: avoid
        # surprise restarts across a 1000-host fleet.)
        return 0
    fi

    local deb
    if ! deb="$(resolve_deb)"; then
        die "no .deb found. Set NS_DEB_PATH to a file/glob or NS_DEB_URL to a download URL."
    fi
    log "Installing package from: $deb"

    # Prefer `apt install ./file.deb` which resolves dependencies automatically.
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        if ! apt-get install -y --no-install-recommends "$deb"; then
            warn "apt-get install of .deb failed; trying dpkg -i + apt-get -f install."
            if ! dpkg -i "$deb"; then
                log "dpkg -i reported errors (likely missing deps); attempting fix."
            fi
            apt-get -f install -y || die "dependency resolution failed for $deb."
        fi
    else
        # No apt: dpkg -i then bail if deps are unmet (can't auto-resolve).
        dpkg -i "$deb" || die "dpkg -i failed and apt-get is unavailable to fix dependencies."
    fi

    dpkg -s "$DEB_PKG_NAME" >/dev/null 2>&1 || die "package not registered after install."
    log "Package '$DEB_PKG_NAME' installed."
}

install_deb

# Confirm the binary is present after install.
[ -x "$NS_BIN" ] || die "expected binary $NS_BIN not found/executable after install."

# =============================================================================
# Step 2: Ensure the systemd service is enabled + running (idempotent)
# =============================================================================

ensure_service() {
    systemctl daemon-reload 2>/dev/null || true

    # The .deb may or may not have registered the unit. If systemd doesn't know
    # the unit, use the binary's own installer (verified: enables + starts).
    if ! systemctl list-unit-files "$SERVICE" >/dev/null 2>&1 \
       || ! systemctl cat "$SERVICE" >/dev/null 2>&1; then
        log "Service unit not registered; running '$NS_BIN --install-service'."
        "$NS_BIN" --install-service || die "--install-service failed."
        systemctl daemon-reload 2>/dev/null || true
    fi

    if ! systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then
        log "Enabling $SERVICE."
        systemctl enable "$SERVICE" || die "failed to enable $SERVICE."
    else
        log "$SERVICE already enabled."
    fi

    if ! systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        log "Starting $SERVICE."
        systemctl start "$SERVICE" || die "failed to start $SERVICE."
    else
        log "$SERVICE already active."
    fi

    # Wait for the service to come up so IPC-backed CLI calls succeed.
    local i
    for i in $(seq 1 30); do
        if systemctl is-active --quiet "$SERVICE"; then
            return 0
        fi
        sleep 1
    done
    die "$SERVICE did not become active within 30s."
}

ensure_service

# Give the IPC socket a brief moment after the service is reported active.
# (The privileged CLI talks to the running service over IPC.)
sleep 2

# =============================================================================
# Step 3: Generate + set a unique strong permanent password (idempotent)
# =============================================================================

gen_password() {
    # 24 chars, URL/shell-safe alphabet, from a CSPRNG. Unique per host/run.
    # Avoids quoting hazards by restricting to [A-Za-z0-9._-].
    local pw
    pw="$(LC_ALL=C tr -dc 'A-Za-z0-9._-' < /dev/urandom | head -c 24 || true)"
    # Guard against a short read.
    [ "${#pw}" -ge 24 ] || die "failed to generate a 24-char password from /dev/urandom."
    printf '%s' "$pw"
}

PASSWORD=""

set_password() {
    if [ -f "$PW_MARKER" ]; then
        # Already provisioned a password on this host. Re-read the saved value so
        # we can still (re-)register it in the address book idempotently. The
        # marker stores the password 0600 root-only.
        log "Password already set previously (marker present); reusing stored value."
        PASSWORD="$(cat "$PW_MARKER")"
        [ -n "$PASSWORD" ] || die "password marker present but empty: $PW_MARKER"
        return 0
    fi

    PASSWORD="$(gen_password)"
    log "Setting permanent password (value redacted)."

    # `nextsession --password <PW>` prints "Done!" on success. Capture output so
    # we can both verify success and avoid leaking the password into logs.
    local out rc
    set +e
    out="$("$NS_BIN" --password "$PASSWORD" 2>&1)"
    rc=$?
    set -e
    if [ $rc -ne 0 ]; then
        die "--password failed (rc=$rc): $(printf '%s' "$out" | redact)"
    fi
    case "$out" in
        *Done*) : ;;  # expected success marker
        *)
            # Not fatal by itself (output wording could vary), but warn loudly.
            warn "--password did not print expected 'Done!' marker; output: $(printf '%s' "$out" | redact)"
            ;;
    esac

    # Persist for idempotent re-runs and RMM collection. Root-only.
    umask 077
    printf '%s' "$PASSWORD" > "$PW_MARKER"
    chmod 600 "$PW_MARKER"
    log "Permanent password set and recorded (root-only marker)."
}

set_password

# =============================================================================
# Step 4: Set approve-mode=password (idempotent)
# =============================================================================
# NOTE: per CLIENT findings these may already be baked into the signed custom.txt
# default/override-settings. Setting them explicitly is harmless and idempotent.

set_option_idempotent() {
    local key="$1" want="$2" cur
    set +e
    cur="$("$NS_BIN" --option "$key" 2>/dev/null)"
    set -e
    cur="$(printf '%s' "$cur" | tr -d '[:space:]')"
    if [ "$cur" = "$want" ]; then
        log "option $key already = $want."
        return 0
    fi
    log "Setting option $key = $want (was: '${cur:-<unset>}')."
    "$NS_BIN" --option "$key" "$want" || die "failed to set option $key=$want."
}

set_option_idempotent approve-mode password
# Recommended companion per findings: use the permanent password for verification.
set_option_idempotent verification-method use-permanent-password

# =============================================================================
# Step 5: Read the device ID
# =============================================================================

read_device_id() {
    local id i
    for i in $(seq 1 10); do
        set +e
        id="$("$NS_BIN" --get-id 2>/dev/null | tr -d '[:space:]')"
        set -e
        # IDs are numeric per findings; accept a non-empty numeric string.
        case "$id" in
            ''|*[!0-9]*) ;;            # empty or non-numeric -> retry
            *) printf '%s' "$id"; return 0 ;;
        esac
        sleep 1
    done
    die "could not read a numeric device id via --get-id (service config not ready?)."
}

DEVICE_ID="$(read_device_id)"
log "Device ID: $DEVICE_ID"

# =============================================================================
# Step 6: Register into the shared address book (API) or fall back to CSV/stdout
# =============================================================================

# Build a JSON array of tags from the comma-separated TAGS.
tags_json() {
    local out="" t IFS=','
    for t in $TAGS; do
        t="$(printf '%s' "$t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -n "$t" ] || continue
        # JSON-escape (tags are simple, but be safe with quotes/backslashes).
        t="$(printf '%s' "$t" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
        if [ -z "$out" ]; then out="\"$t\""; else out="$out,\"$t\""; fi
    done
    printf '[%s]' "$out"
}

# Minimal JSON string escaper for the fields we send.
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

register_via_api() {
    [ -n "$API_TOKEN" ]        || return 1
    [ -n "$AB_USER_ID" ]       || { warn "NS_API_TOKEN set but NS_AB_USER_ID missing; skipping API registration."; return 1; }
    [ -n "$AB_COLLECTION_ID" ] || { warn "NS_API_TOKEN set but NS_AB_COLLECTION_ID missing; skipping API registration."; return 1; }
    if [ "$HAVE_CURL" -ne 1 ]; then
        warn "curl not installed; cannot call API. Falling back to CSV/stdout."
        return 1
    fi

    # AB_USER_ID / AB_COLLECTION_ID must be numeric (server expects integers).
    case "$AB_USER_ID" in       *[!0-9]*) die "NS_AB_USER_ID must be numeric." ;; esac
    case "$AB_COLLECTION_ID" in *[!0-9]*) die "NS_AB_COLLECTION_ID must be numeric." ;; esac

    local url="${API_BASE%/}/api/admin/address_book/create"
    local alias_esc host_esc pw_esc tags
    alias_esc="$(json_escape "$HOSTNAME_FQDN")"
    host_esc="$(json_escape "$HOSTNAME_FQDN")"
    pw_esc="$(json_escape "$PASSWORD")"
    tags="$(tags_json)"

    # Body per ADDRESS-BOOK findings (§4). id is a string; ids numeric but the
    # endpoint accepts the peer id as a string per the request struct.
    local body
    body="$(cat <<EOF
{"id":"${DEVICE_ID}","user_id":${AB_USER_ID},"collection_id":${AB_COLLECTION_ID},"alias":"${alias_esc}","hostname":"${host_esc}","username":"","platform":"Linux","tags":${tags},"password":"${pw_esc}","hash":""}
EOF
)"

    log "Registering device $DEVICE_ID into shared address book (collection $AB_COLLECTION_ID)."

    local resp http rc
    set +e
    resp="$(curl -sS -w '\n%{http_code}' \
        --connect-timeout "$CURL_CONNECT_TIMEOUT" \
        --max-time "$CURL_MAX_TIME" \
        --retry "$CURL_RETRIES" --retry-delay 2 \
        -X POST "$url" \
        -H 'Content-Type: application/json' \
        -H "api-token: ${API_TOKEN}" \
        --data-binary "$body" 2>&1)"
    rc=$?
    set -e
    if [ $rc -ne 0 ]; then
        warn "API call transport error (rc=$rc). Falling back to CSV/stdout."
        return 1
    fi

    http="$(printf '%s' "$resp" | tail -n1)"
    local payload
    payload="$(printf '%s' "$resp" | sed '$d')"

    case "$http" in
        2*)
            # Some RustDesk-API handlers return HTTP 200 with an error code in the
            # JSON body. Treat an explicit non-zero "code" or "error" as failure.
            # TODO(verify): confirm exact success/duplicate response shape of
            # POST /api/admin/address_book/create against the live server. The
            # findings note it rejects duplicates per (user_id,id,collection_id);
            # a duplicate likely returns an error we should treat as idempotent OK.
            case "$payload" in
                *'"error"'*|*'"msg":"'*[Ee]rror*)
                    # Duplicate entry on re-run is an idempotent success for us.
                    case "$payload" in
                        *[Dd]uplicat*|*[Ee]xist*)
                            log "Device already present in address book (idempotent OK)."
                            return 0
                            ;;
                    esac
                    warn "API returned HTTP $http but body looks like an error: $payload"
                    return 1
                    ;;
            esac
            log "Address-book registration succeeded (HTTP $http)."
            return 0
            ;;
        401|403)
            warn "API auth failed (HTTP $http) — check NS_API_TOKEN is an enabled ADMIN token. Body: $payload"
            return 1
            ;;
        409)
            log "Device already present in address book (HTTP 409, idempotent OK)."
            return 0
            ;;
        *)
            warn "API registration failed (HTTP $http). Body: $payload"
            return 1
            ;;
    esac
}

write_csv() {
    # CSV for RMM collection: hostname,id,password,tags. Created with a header
    # once; appended thereafter. One line per (re-)provision is acceptable for
    # collection, but to keep it idempotent we de-dup by device id.
    umask 077
    local header="hostname,id,password,tags,timestamp"
    if [ ! -f "$CSV_OUT" ]; then
        printf '%s\n' "$header" > "$CSV_OUT"
        chmod 600 "$CSV_OUT"
    fi
    # Drop any prior line for this device id, then append the current record.
    if grep -q ",${DEVICE_ID}," "$CSV_OUT" 2>/dev/null; then
        local tmp
        tmp="$(mktemp "${STATE_DIR}/csv.XXXXXX")"
        grep -v ",${DEVICE_ID}," "$CSV_OUT" > "$tmp" || true
        mv "$tmp" "$CSV_OUT"
        chmod 600 "$CSV_OUT"
    fi
    # CSV-quote fields that may contain commas/quotes (password uses a safe
    # alphabet, but quote defensively anyway).
    local q_host q_pw q_tags
    q_host="\"$(printf '%s' "$HOSTNAME_FQDN" | sed 's/"/""/g')\""
    q_pw="\"$(printf '%s' "$PASSWORD" | sed 's/"/""/g')\""
    q_tags="\"$(printf '%s' "$TAGS" | sed 's/"/""/g')\""
    printf '%s,%s,%s,%s,%s\n' \
        "$q_host" "$DEVICE_ID" "$q_pw" "$q_tags" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        >> "$CSV_OUT"
    log "Wrote record to CSV: $CSV_OUT"
}

emit_stdout_record() {
    # Machine-collectable single-line JSON on stdout for the RMM to scrape.
    # This is the ONLY place the password is printed to stdout (by design, so the
    # RMM can capture it when API registration is not used).
    printf '{"hostname":"%s","id":"%s","password":"%s","tags":"%s"}\n' \
        "$(json_escape "$HOSTNAME_FQDN")" \
        "$DEVICE_ID" \
        "$(json_escape "$PASSWORD")" \
        "$(json_escape "$TAGS")"
}

# Try the API first; on any failure or if not configured, fall back to CSV+stdout.
if register_via_api; then
    # Even on API success, write the CSV so the RMM has a local artifact and the
    # password is recoverable for the helpdesk. (Comment out if you want the
    # password to live ONLY in the address book.)
    write_csv
    emit_stdout_record
    log "Provisioning complete (registered via API)."
else
    log "API registration not used or failed; emitting record to CSV + stdout for RMM collection."
    write_csv
    emit_stdout_record
    log "Provisioning complete (record emitted for RMM collection)."
fi

exit 0
