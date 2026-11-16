#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — system info in a floating terminal (polybar launcher right-click)
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
ab_term -o initial_window_width=100c -o initial_window_height=26c -- bash -c '
  if command -v fastfetch >/dev/null 2>&1; then fastfetch
  elif command -v neofetch >/dev/null 2>&1; then neofetch
  else uname -a; echo; free -h; echo; df -h /; fi
  read -r -s -n1'
