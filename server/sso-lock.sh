#!/usr/bin/env bash
# Lock the console + client to Entra SSO only (disable password login).
# Run with sudo (containers are rootful). Re-runs the canonical deploy with the flag.
set -euo pipefail
cd "$(dirname "$0")/.."
echo ">> Locking to SSO-only (disable-pwd-login=true)..."
SSO_ONLY=true bash server/deploy-api.sh
