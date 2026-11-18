#!/usr/bin/env bash
# AutoBSPWN v3.4.0 — HiDPI + multi-monitor (automatic; bspwmrc runs it)
#   monitors.sh [--apply]        new outputs on / unplugged off (xrandr), Xft.dpi + rofi DPI,
#                                desktops split across the monitors, one polybar per monitor
#   monitors.sh --apply --no-bar   same without relaunching polybar (bspwmrc does it later)
#   monitors.sh --watch          follow plug / unplug every 3 s (one instance; bspwmrc starts it)
#   monitors.sh --dpi [OUTPUT]   DPI for that output (default: primary)   --list   outputs
# DPI: physical size from xrandr → 96/120/144/168/192 (VMs report 0 mm → 96, or 192 when the
# screen is 3200+ px wide). Force it in ~/.config/autobspwn/state with dpi=144 (dpi=auto = default).
# Desktops (state: desktops=split, default): I–X split in order (2 monitors: I–V / VI–X);
# desktops=each keeps I–X on every monitor (the pre-3.4 layout). xrandr=off: never touch outputs.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

ROFI_DPI="$HOME/.config/rofi/dpi.rasi"

# name <TAB> connected 0|1 <TAB> geometry WxH+X+Y or - <TAB> width mm <TAB> primary 0|1
outputs() {
  ab_has xrandr || return 0
  xrandr --current 2>/dev/null | awk '/^[^ \t]+ (connected|disconnected)/ {
      geo = "-"; mm = 0; prim = 0
      for (i = 3; i <= NF; i++) {
        if ($i == "primary") prim = 1
        else if (geo == "-" && $i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) geo = $i
        else if (mm == 0 && $i ~ /^[0-9]+mm$/) { mm = $i; sub(/mm$/, "", mm) }
      }
      print $1 "\t" ($2 == "connected" ? 1 : 0) "\t" geo "\t" mm "\t" prim }'
}

forced_dpi() {
  local d=${AUTOBSPWN_DPI:-}
  [ -n "$d" ] || d=$(ab_state_get dpi auto)
  [[ $d =~ ^[0-9]+$ ]] && (( d >= 48 && d <= 480 )) && { echo "$d"; return 0; }
  return 1
}

# dpi_for [output]  (empty = primary, else the first active output)
dpi_for() {
  local want=${1:-} name conn geo mm prim px=0 mmw=0 pick=''
  forced_dpi && return 0
  while IFS=$'\t' read -r name conn geo mm prim; do
    [ "$geo" != - ] || continue
    if [ -n "$want" ]; then
      [ "$name" = "$want" ] || continue
      px=${geo%%x*}; mmw=$mm; break
    fi
    if [ -z "$pick" ] || [ "$prim" = 1 ]; then pick=$name; px=${geo%%x*}; mmw=$mm; fi
    [ "$prim" = 1 ] && break
  done < <(outputs)
  ab_calc_dpi "$px" "$mmw"
}

apply_xrandr() {
  ab_has xrandr || return 0
  [ "$(ab_state_get xrandr auto)" = off ] && return 0
  local name conn geo mm prim last='' lastx=-1 x w changed=0
  local -a on=() off=()
  while IFS=$'\t' read -r name conn geo mm prim; do
    if [ "$geo" != - ]; then
      if [ "$conn" = 0 ]; then off+=("$name"); continue; fi
      w=${geo%%x*}; x=${geo#*+}; x=${x%%+*}
      if (( x + w > lastx )); then lastx=$((x + w)); last=$name; fi
    elif [ "$conn" = 1 ]; then
      on+=("$name")
    fi
  done < <(outputs)
  for name in "${off[@]}"; do xrandr --output "$name" --off 2>/dev/null && changed=1; done
  for name in "${on[@]}"; do
    if [ -n "$last" ]; then xrandr --output "$name" --auto --right-of "$last" 2>/dev/null && changed=1
    else xrandr --output "$name" --auto 2>/dev/null && changed=1; fi
    last=$name
  done
  [ "$changed" = 1 ] && sleep 0.5   # let bspwm see the new monitors
  return 0
}

apply_dpi() {
  local d want
  d=$(dpi_for)
  if ab_has xrdb && [ -n "${DISPLAY:-}" ]; then
    printf 'Xft.dpi: %s\n' "$d" | xrdb -merge 2>/dev/null || true
  fi
  if [ "$d" = 96 ]; then want='/* AutoBSPWN monitors.sh: 96 dpi (default) */'
  else want="/* AutoBSPWN monitors.sh (HiDPI) */ configuration { dpi: $d; }"; fi
  if [ -d "$(dirname "$ROFI_DPI")" ] && [ "$(cat "$ROFI_DPI" 2>/dev/null)" != "$want" ]; then
    printf '%s\n' "$want" >"$ROFI_DPI"
  fi
  echo "$d"
}

apply_desktops() {
  ab_has bspc || return 0
  local -a mons=() sets=()
  local i cur
  mapfile -t mons < <(bspc query -M --names 2>/dev/null)
  if [ ${#mons[@]} -eq 0 ]; then
    bspc monitor -d I II III IV V VI VII VIII IX X 2>/dev/null || true
    return 0
  fi
  if [ "$(ab_state_get desktops split)" = each ]; then
    for i in "${!mons[@]}"; do sets+=("I II III IV V VI VII VIII IX X"); done
  else
    mapfile -t sets < <(ab_split_desktops "${#mons[@]}")
  fi
  for i in "${!mons[@]}"; do
    cur=$(bspc query -D -m "${mons[$i]}" --names 2>/dev/null | paste -sd' ' -)
    [ "$cur" = "${sets[$i]}" ] && continue
    # shellcheck disable=SC2086  # one word per desktop name
    bspc monitor "${mons[$i]}" -d ${sets[$i]} 2>/dev/null || true
  done
}

apply() {
  local bar=1
  [ "${1:-}" = --no-bar ] && bar=0
  apply_xrandr
  apply_dpi >/dev/null
  apply_desktops
  if [ "$bar" = 1 ] && [ -x "$HOME/.config/polybar/launch.sh" ]; then
    setsid -f "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 </dev/null || true
  fi
}

signature() {
  { outputs | cut -f1-3; ab_has bspc && bspc query -M --names 2>/dev/null; } | paste -sd' ' -
}

watch() {
  ab_has xrandr || exit 0
  exec 9>"$AB_CACHE/monitors-watch.lock"
  if ab_has flock && ! flock -n 9; then exit 0; fi   # already watching
  local last now fails=0
  last=$(signature)
  while :; do
    sleep 3
    pgrep -u "$(id -u)" -x bspwm >/dev/null 2>&1 || exit 0
    if ! now=$(signature) || [ -z "$now" ]; then
      fails=$((fails + 1)); (( fails > 5 )) && exit 0; continue
    fi
    fails=0
    [ "$now" = "$last" ] && continue
    sleep 1                                   # plugging is noisy: settle, then apply once
    apply
    last=$(signature)
  done
}

case "${1:---apply}" in
  --apply)    apply "${2:-}" ;;
  --watch)    watch ;;
  --dpi)      dpi_for "${2:-}" ;;
  --desktops) apply_desktops ;;
  --list)     outputs ;;
  -h|--help)  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "uso: monitors.sh [--apply [--no-bar]|--watch|--dpi [salida]|--desktops|--list]" >&2; exit 2 ;;
esac
