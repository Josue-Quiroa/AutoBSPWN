#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — compatibility shim: target-scan.sh quick|full <ip>  →  tscan fast|full <ip>
# (the Target HUD calls tscan directly since v3.3; see `tscan --help`)
mode=${1:-}; ip=${2:-}
case "$mode" in quick) mode=fast ;; full) ;; *) echo "Uso: target-scan.sh quick|full <ip>  (mejor: tscan fast|full|udp|ad)"; exit 1 ;; esac
t="$HOME/.local/bin/tscan"
[ -x "$t" ] || t=$(command -v tscan 2>/dev/null || true)
[ -n "$t" ] || { echo "tscan no está instalado (./Install.sh --update)"; exit 1; }
exec "$t" "$mode" ${ip:+"$ip"}
