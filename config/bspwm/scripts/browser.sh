#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — open the first installed browser (Super+Shift+f)
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
ab_browser "${1:-about:blank}" || true
