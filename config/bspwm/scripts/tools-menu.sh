#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — quick launcher for pentest tools (rofi)
#   tools-menu.sh               rofi menu (Super+p)
#   tools-menu.sh --run NAME    launch one tool directly (e.g. --run burpsuite → Super+Shift+b)
# Only tools that are installed are listed. Java GUIs get _JAVA_AWT_WM_NONREPARENTING=1
# (without it Burp / Ghidra / ZAP draw grey, empty windows under bspwm).
# Add your own entries in ~/.config/bspwm/tools.list:
#   Nombre|java|gui|comando arg…      (java/gui: 1 or 0; gui=0 opens in a terminal)
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
RUN=
[ "${1:-}" = --run ] && RUN=${2:-}
[ -n "$RUN" ] || ab_need_rofi

# label | java | gui | candidates (first one installed wins; separated by ';')
BUILTIN='
󰒃  Burp Suite|1|1|burpsuite;burpsuite-pro;BurpSuiteCommunity;BurpSuitePro
󰖟  OWASP ZAP|1|1|zaproxy;owasp-zap;zap.sh
󰖟  Caido|0|1|caido
󰛳  Wireshark|0|1|wireshark
󰆼  BloodHound|1|1|bloodhound;BloodHound;bloodhound-ce
󰆼  Neo4j console (sudo)|1|0|sudo neo4j console
󰘦  Ghidra|1|1|ghidra;ghidraRun
󰘦  Cutter|0|1|cutter;Cutter
󰘦  jd-gui|1|1|jd-gui
󰘦  IDA Free|0|1|ida64;ida
󰕥  Metasploit|0|0|msfconsole
󰣀  Armitage|1|1|armitage
󰕥  Maltego|1|1|maltego
󰖟  Postman|0|1|postman;Postman
󰍉  Zenmap|0|1|zenmap
󰢹  Remmina|0|1|remmina
󰋊  Responder (sudo)|0|0|sudo responder
󰖟  Firefox|0|1|firefox;firefox-esr
'

LABELS=(); JAVA=(); GUI=(); CMDS=()

add_tool() {
  local label=$1 java=$2 gui=$3 cands=$4 c first bin
  IFS=';' read -r -a list <<<"$cands"
  for c in "${list[@]}"; do
    c=${c#"${c%%[![:space:]]*}"}
    [ -n "$c" ] || continue
    first=${c%% *}
    bin=$first
    [ "$first" = sudo ] && { bin=${c#sudo }; bin=${bin%% *}; }
    if ab_has "$bin"; then
      LABELS+=("$label"); JAVA+=("$java"); GUI+=("$gui"); CMDS+=("$c")
      return 0
    fi
  done
  return 1
}

load() {
  local label java gui cands
  while IFS='|' read -r label java gui cands; do
    { [ -z "$label" ] || [ -z "$cands" ]; } && continue
    case "$label" in \#*) continue ;; esac
    add_tool "$label" "${java:-0}" "${gui:-1}" "$cands" || true
  done
}

load <<<"$BUILTIN"
[ -f "$HOME/.config/bspwm/tools.list" ] && load <"$HOME/.config/bspwm/tools.list"

if [ ${#LABELS[@]} -eq 0 ]; then
  ab_notify "No se encontró ninguna herramienta instalada"
  exit 0
fi

if [ -n "$RUN" ]; then
  idx=
  for i in "${!CMDS[@]}"; do
    c=${CMDS[$i]#sudo }
    case "${c%% *}" in "$RUN"|"$RUN"-*|*"$RUN"*) idx=$i; break ;; esac
  done
  [ -n "$idx" ] || { ab_notify "$RUN no está instalado (ver --tools en Install.sh)"; exit 1; }
else
  idx=$(printf '%s\n' "${LABELS[@]}" | ab_menu "Tools" -format i \
    -mesg "${#LABELS[@]} herramientas instaladas · extra: ~/.config/bspwm/tools.list") || exit 0
fi
[[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt ${#LABELS[@]} ] || exit 0

read -r -a argv <<<"${CMDS[$idx]}"
if [ "${JAVA[$idx]}" = 1 ]; then
  export _JAVA_AWT_WM_NONREPARENTING=1
fi
if [ "${GUI[$idx]}" = 1 ]; then
  # Detach so closing rofi / sxhkd reloads never kill the tool
  setsid -f "${argv[@]}" >/dev/null 2>&1 </dev/null
else
  ab_term_hold "${argv[@]}"
fi
ab_notify "Lanzando ${LABELS[$idx]#*  }"
