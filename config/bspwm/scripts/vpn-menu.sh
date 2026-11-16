#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — VPN / lab switcher (rofi)
# Profiles:
#   ~/vpn/*.ovpn            OpenVPN (HTB, THM, OffSec…)
#   ~/vpn/*.conf            WireGuard if it has [Interface], otherwise OpenVPN
#   nmcli                   NetworkManager connections of type vpn / wireguard
# Lab-switcher semantics: connecting a profile first drops the others
# (set AUTOBSPWN_VPN_MULTI=1 to allow several at once).
#   vpn-menu.sh [--reconnect | --down]
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"

STATUS="$HOME/.config/polybar/scripts/vpn_status.sh"
LAST="$AB_CACHE/vpn_last"          # type<TAB>id of the last profile used
ACTIVE="$AB_CACHE/vpn_active"      # type<TAB>id of the profile started by this menu
PIDF="/tmp/autobspwn-openvpn-$(id -u).pid"
LOGF="/tmp/autobspwn-openvpn-$(id -u).log"
mkdir -p "$AB_VPN_DIR" 2>/dev/null || true

# Everything that needs root runs in ONE privileged call (one password prompt).
# shellcheck disable=SC2016
ROOT_SNIPPET='
while [ $# -gt 0 ]; do
  case "$1" in
    kill)   kill "$2" 2>/dev/null || true; shift 2 ;;
    wgdown) wg-quick down "$2" || true; shift 2 ;;
    wgup)   wg-quick up "$2"; shift 2 ;;
    ovpn)   openvpn --cd "$(dirname "$2")" --config "$2" --daemon autobspwn-vpn --writepid "$3" --log "$4"
            chmod 644 "$3" "$4" 2>/dev/null || true; shift 4 ;;
    ovpnfg) exec openvpn --cd "$(dirname "$2")" --config "$2" ;;
    *) shift ;;
  esac
done'

vpn_ifaces() { [ -x "$STATUS" ] && "$STATUS" --ifaces; }

is_wg_file() { grep -qE '^[[:space:]]*\[Interface\]' "$1" 2>/dev/null; }

# Config asks for user/pass interactively (no credentials file) → must run in a terminal
needs_tty() { grep -qE '^[[:space:]]*auth-user-pass[[:space:]]*$' "$1" 2>/dev/null; }

wg_name() { local b; b=$(basename "$1"); printf '%s\n' "${b%.conf}"; }

ovpn_pids() {
  # Only openvpn processes that run a config from ~/vpn (never touch NM's own)
  pgrep -a -x openvpn 2>/dev/null | grep -F -- "$AB_VPN_DIR/" | awk '{print $1}'
  if [ -s "$PIDF" ]; then
    local p
    p=$(tr -dc '0-9' <"$PIDF")
    [ -n "$p" ] && [ "$(ps -p "$p" -o comm= 2>/dev/null)" = openvpn ] && echo "$p"
  fi
}

ovpn_running() {
  # $1 = config path
  pgrep -a -x openvpn 2>/dev/null | grep -qF -- "$1"
}

# ---- profile list ---------------------------------------------------------
TYPES=(); IDS=(); LABELS=()
add_profile() { TYPES+=("$1"); IDS+=("$2"); LABELS+=("$3"); }

load_profiles() {
  local f n st active_nm
  shopt -s nullglob
  for f in "$AB_VPN_DIR"/*.ovpn "$AB_VPN_DIR"/*.conf; do
    n=$(basename "$f")
    if [[ "$f" == *.conf ]] && is_wg_file "$f"; then
      st="○"; ip link show "$(wg_name "$f")" >/dev/null 2>&1 && st="●"
      add_profile wgfile "$f" "$st  ${n%.conf}   (WireGuard)"
    else
      st="○"; ovpn_running "$f" && st="●"
      add_profile ovpn "$f" "$st  ${n%.*}   (OpenVPN)"
    fi
  done
  shopt -u nullglob
  if ab_has nmcli; then
    active_nm=$(nmcli -t -f NAME c show --active 2>/dev/null | sed 's/\\:/:/g')
    local line t
    while IFS= read -r line; do
      t=${line##*:}                       # TYPE never contains ':'
      n=${line%:*}; n=${n//\\:/:}          # nmcli -t escapes ':' in names as '\:'
      case "$t" in vpn|wireguard) ;; *) continue ;; esac
      [ -n "$n" ] || continue
      st="○"; grep -qxF -- "$n" <<<"$active_nm" && st="●"
      add_profile nm "$n" "$st  $n   (nmcli $t)"
    done < <(nmcli -t -f NAME,TYPE c show 2>/dev/null)
  fi
}

# ---- connect / disconnect -------------------------------------------------
# Fills ROOT_ARGS with the root steps needed to drop every VPN started from ~/vpn
ROOT_ARGS=()
plan_down_files() {
  local p f
  while read -r p; do
    [ -n "$p" ] && ROOT_ARGS+=(kill "$p")
  done < <(ovpn_pids | sort -u)
  shopt -s nullglob
  for f in "$AB_VPN_DIR"/*.conf; do
    is_wg_file "$f" && ip link show "$(wg_name "$f")" >/dev/null 2>&1 && ROOT_ARGS+=(wgdown "$f")
  done
  shopt -u nullglob
}

down_nm() {
  ab_has nmcli || return 0
  local n
  while IFS= read -r n; do
    [ -n "$n" ] && nmcli c down id "$n" >/dev/null 2>&1
  done < <(nmcli -t -f NAME,TYPE c show --active 2>/dev/null | awk -F: '$2=="vpn" || $2=="wireguard"{print $1}')
}

run_root_plan() {
  [ ${#ROOT_ARGS[@]} -gt 0 ] || return 0
  ab_root bash -c "$ROOT_SNIPPET" _ "${ROOT_ARGS[@]}"
}

# Notify once the tunnel has an IP (background, max ~40s)
watch_up() {
  local before=$1 label=$2
  (
    for _ in $(seq 1 40); do
      sleep 1
      now=$(vpn_ifaces)
      if [ -n "$now" ] && [ "$now" != "$before" ]; then
        ab_notify "$label → $(head -n1 <<<"$now" | tr '\t' ' ')" "VPN conectada"
        exit 0
      fi
    done
    ab_notify "$label: sin IP de túnel tras 40s (revisa $LOGF o nmcli)" "VPN"
  ) >/dev/null 2>&1 &
}

disconnect_all() {
  ROOT_ARGS=()
  plan_down_files
  run_root_plan
  down_nm
  rm -f "$ACTIVE"
}

connect() {
  local type=$1 id=$2 before label
  before=$(vpn_ifaces)
  label=$(basename "$id"); label=${label%.*}
  ROOT_ARGS=()
  if [ "${AUTOBSPWN_VPN_MULTI:-0}" != 1 ]; then
    plan_down_files
    down_nm
    before=
  fi
  case "$type" in
    ovpn)
      ab_has openvpn || { ab_notify "openvpn no está instalado"; return 1; }
      if needs_tty "$id"; then
        # Interactive credentials: foreground in a terminal (closing it drops the VPN)
        ab_term --title "VPN $label" -- sudo bash -c "$ROOT_SNIPPET" _ "${ROOT_ARGS[@]}" ovpnfg "$id"
      else
        ROOT_ARGS+=(ovpn "$id" "$PIDF" "$LOGF")
        run_root_plan
      fi
      ;;
    wgfile)
      ab_has wg-quick || { ab_notify "wireguard-tools no está instalado"; return 1; }
      local n; n=$(wg_name "$id")
      if ! [[ "$n" =~ ^[A-Za-z0-9_=+.-]{1,15}$ ]]; then
        ab_notify "Renombra $id: el nombre de interfaz WireGuard debe tener ≤15 caracteres [A-Za-z0-9_=+.-]"
        return 1
      fi
      ROOT_ARGS+=(wgup "$id")
      run_root_plan
      ;;
    nm)
      run_root_plan
      ( out=$(nmcli c up id "$id" 2>&1) || ab_notify "${out:0:200}" "VPN error: $id" ) >/dev/null 2>&1 &
      ;;
    *) return 1 ;;
  esac
  printf '%s\t%s\n' "$type" "$id" >"$LAST"
  printf '%s\t%s\n' "$type" "$id" >"$ACTIVE"
  ab_notify "Conectando $label…" "VPN"
  watch_up "$before" "$label"
}

reconnect() {
  [ -s "$LAST" ] || { ab_notify "No hay VPN previa para reconectar"; return 1; }
  local type id
  IFS=$'\t' read -r type id <"$LAST"
  if [ "$type" != nm ] && [ ! -f "$id" ]; then
    ab_notify "Ya no existe: $id"
    return 1
  fi
  if [ "${AUTOBSPWN_VPN_MULTI:-0}" = 1 ]; then
    disconnect_all
    sleep 1
  fi
  connect "$type" "$id"
}

case "${1:-}" in
  --reconnect) reconnect; exit $? ;;
  --down)      disconnect_all; ab_notify "VPN desconectada"; exit 0 ;;
esac

ab_need_rofi
load_profiles
mapfile -t up < <(vpn_ifaces)
if [ ${#up[@]} -gt 0 ]; then
  mesg="󰒃 Activa: $(printf '%s  ' "${up[@]}" | tr '\t' ' ')"
else
  mesg="󰒲 Sin VPN activa · perfiles en ~/vpn (*.ovpn, WireGuard *.conf) o nmcli"
fi

ACTIONS=()
lines=("${LABELS[@]}")
if [ -s "$LAST" ]; then
  last=$(cut -f2 "$LAST"); last=$(basename "$last")
  lines+=("󰑓  Reconectar (${last%.*})"); ACTIONS+=(reconnect)
fi
if [ ${#up[@]} -gt 0 ] || [ -s "$ACTIVE" ]; then
  lines+=("󰅖  Desconectar todo"); ACTIONS+=(down)
fi
if [ ${#up[@]} -gt 0 ]; then
  lines+=("󰆏  Copiar IP VPN (${up[0]#*$'\t'})"); ACTIONS+=(copy)
fi
if [ -s "$LOGF" ]; then
  lines+=("󰦪  Ver log OpenVPN"); ACTIONS+=(log)
fi
lines+=("󰉋  Abrir carpeta ~/vpn"); ACTIONS+=(folder)

idx=$(printf '%s\n' "${lines[@]}" | ab_menu "VPN" -format i -mesg "$mesg") || exit 0
[[ "$idx" =~ ^[0-9]+$ ]] || exit 0
np=${#LABELS[@]}
if [ "$idx" -lt "$np" ]; then
  t=${TYPES[$idx]}; id=${IDS[$idx]}
  if [[ "${LABELS[$idx]}" == "●"* ]]; then
    # Selecting an active profile disconnects it
    case "$t" in
      nm) nmcli c down id "$id" >/dev/null 2>&1 ;;
      *)  disconnect_all ;;
    esac
    ab_notify "Desconectado: $(basename "$id")" "VPN"
  else
    connect "$t" "$id"
  fi
  exit 0
fi
case "${ACTIONS[$((idx - np))]:-}" in
  reconnect) reconnect ;;
  down)      disconnect_all; ab_notify "VPN desconectada" ;;
  copy)      ab_copy "${up[0]#*$'\t'}" && ab_notify "Copiado: ${up[0]#*$'\t'}" ;;
  log)       ab_term --title "OpenVPN log" -- less +F "$LOGF" ;;
  folder)    ab_files "$AB_VPN_DIR" ;;
esac
