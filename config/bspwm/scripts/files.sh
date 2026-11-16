#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — open a file manager (Super+e) without letting caja/nemo take over the desktop
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
ab_files "${1:-$HOME}"
