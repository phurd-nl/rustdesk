#!/usr/bin/env bash
# BREAK-GLASS: restore local password login (e.g. if SSO/Entra is unavailable).
# Run with sudo. After this, the local admin password works again at /_admin/.
set -euo pipefail
cd "$(dirname "$0")/.."
echo ">> Restoring password login (disable-pwd-login=false)..."
SSO_ONLY=false bash server/deploy-api.sh
