#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — nmap helper for the Target HUD (runs inside a terminal).
#   target-scan.sh quick|full <ip>
# Output: ~/targets/<ip>/nmap/*  +  ~/targets/<ip>/ports.txt (comma list, used by the HUD)
# Runs unprivileged (TCP connect scan). For SYN scans run nmap with sudo yourself.
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"

mode=${1:-}
ip=${2:-}
if [ -z "$ip" ] || ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Uso: target-scan.sh quick|full <ip>"
  exit 1
fi
ab_has nmap || { echo "nmap no está instalado (sudo apt install nmap)"; exit 1; }
dir=$(ab_target_dir "$ip")
out="$dir/nmap"
ts=$(date +%Y%m%d-%H%M%S)

save_ports() {
  # $1 = .gnmap file. Prints the ports found by THIS scan; ports.txt keeps the union.
  [ -f "$1" ] || return 1
  local p all
  p=$(grep -oE '[0-9]+/open/' "$1" | cut -d/ -f1 | sort -un | paste -sd, -)
  [ -n "$p" ] || return 1
  all=$p
  if [ -s "$dir/ports.txt" ]; then
    all=$(printf '%s,%s' "$(cat "$dir/ports.txt")" "$p" | tr ',' '\n' | grep -E '^[0-9]+$' | sort -un | paste -sd, -)
  fi
  printf '%s\n' "$all" >"$dir/ports.txt"
  printf '%s\n' "$p"
}

case "$mode" in
  quick)
    echo "[*] Nmap rápido (top 1000 TCP) → $out/quick-$ts.*"
    nmap -Pn -n -T4 --top-ports 1000 --open -oA "$out/quick-$ts" "$ip"
    ports=$(save_ports "$out/quick-$ts.gnmap" || true)
    ;;
  full)
    echo "[*] Fase 1: todos los puertos TCP → $out/allports-$ts.*"
    nmap -Pn -n -p- --min-rate 3000 --open -oA "$out/allports-$ts" "$ip"
    ports=$(save_ports "$out/allports-$ts.gnmap" || true)
    if [ -n "$ports" ]; then
      echo
      echo "[*] Fase 2: -sCV en $ports → $out/targeted-$ts.*"
      nmap -Pn -n -sC -sV -p "$ports" -oA "$out/targeted-$ts" "$ip"
    fi
    ;;
  *)
    echo "Modo desconocido: $mode (quick|full)"
    exit 1
    ;;
esac

if [ -n "${ports:-}" ]; then
  ab_notify "$ip → $ports" "Nmap listo"
  echo
  echo "[+] Puertos abiertos: $ports  (guardado en $dir/ports.txt)"
else
  ab_notify "$ip: sin puertos abiertos (¿host caído o filtrado?)" "Nmap listo"
  echo "[-] Sin puertos abiertos"
fi
