#!/usr/bin/env bash
# AutoBSPWN v3.4.3 — HiDPI + multi-monitor (automatic; bspwmrc runs it)
#   monitors.sh [--apply]        new outputs on / unplugged off (xrandr, see policy), bspwm monitors
#                                synced with xrandr, Xft.dpi + rofi DPI, desktops split across the
#                                monitors, wallpaper repainted, one polybar per monitor
#   monitors.sh --apply --no-bar   same without relaunching polybar / wallpaper (bspwmrc does it)
#   monitors.sh --watch          follow plug / unplug / resolution changes (one instance; polls
#                                every 2 s, applies once the layout is stable for 1 s)
#   monitors.sh --dpi [OUTPUT]   DPI for that output (default: primary)   --list   outputs
#   monitors.sh --status         xrandr policy, outputs and bspwm monitors (diagnostics)
# DPI: physical size from xrandr → 96/120/144/168/192 (VMs report 0 mm → 96, or 192 when the
# screen is 3200+ px wide). Force it in ~/.config/autobspwn/state with dpi=144 (dpi=auto = default).
# Desktops (state: desktops=split, default): I–X split in order (2 monitors: I–V / VI–X);
# desktops=each keeps I–X on every monitor (the pre-3.4 layout).
# xrandr policy (state xrandr=auto|on|off): auto (default) turns new outputs on / unplugged ones
# off, EXCEPT in VMware / VirtualBox / SPICE guests where open-vm-tools (vmware-user), VBoxClient
# or spice-vdagent own the layout: there we only react to what they set. on = always, off = never.
# v3.4.2: changes are detected by full geometry (size + position of every output, root size,
# RandR monitors and bspwm's monitors), not only by name; bspwm's monitors are re-synced with
# xrandr when they disagree (resize / add / remove ghosts), then desktops, wallpaper and bars.
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

# virt: AUTOBSPWN_VIRT (tests) or systemd-detect-virt (none, vmware, oracle, kvm, …)
virt() {
  local v=${AUTOBSPWN_VIRT:-}
  [ -n "$v" ] || { ab_has systemd-detect-virt && v=$(systemd-detect-virt -v 2>/dev/null); }
  printf '%s\n' "${v:-none}"
}

# guest_agent: the program that resizes the screen for the host window, if any
guest_agent() {
  local u; u=$(id -u)
  if [ -n "${AUTOBSPWN_GUEST_AGENT+x}" ]; then printf '%s\n' "$AUTOBSPWN_GUEST_AGENT"; return 0; fi
  if pgrep -u "$u" -f 'vmware-user|vmtoolsd.*vmusr' >/dev/null 2>&1; then echo vmware-user
  elif pgrep -u "$u" -f 'VBoxClient.*(vmsvga|display)' >/dev/null 2>&1; then echo VBoxClient
  elif pgrep -f spice-vdagent >/dev/null 2>&1; then echo spice-vdagent
  else
    case "$(virt)" in vmware) echo 'vmware (open-vm-tools)' ;; oracle) echo 'virtualbox (VBoxClient)' ;; esac
  fi
}

# xrandr_policy → on | off  (+ reason on stderr-free 2nd line for --status)
xrandr_policy() {
  local p a
  p=$(ab_state_get xrandr auto)
  case "$p" in
    on|off) printf '%s\nstate xrandr=%s\n' "$p" "$p" ;;
    *) a=$(guest_agent)
       if [ -n "$a" ]; then printf 'off\nauto: lo gestiona %s (solo se reacciona)\n' "$a"
       else printf 'on\nauto: sin agente de VM\n'; fi ;;
  esac
}

apply_xrandr() {
  ab_has xrandr || return 0
  [ "$(xrandr_policy | head -n1)" = off ] && return 0
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

# active xrandr outputs: name <TAB> WxH+X+Y   (connected or not: what is really lit)
# root (screen) size: "W H" or nothing
root_size() {
  xrandr --current 2>/dev/null | sed -n 's/^Screen [0-9]*:.*current \([0-9]*\) x \([0-9]*\).*/\1 \2/p' | head -n1
}

# active xrandr outputs that bspwm should have: name <TAB> WxH+X+Y
# v3.4.3: only CONNECTED outputs with a real mode. VMware, when you leave the 2-monitor / full
# screen mode, may leave Virtual-2 "disconnected" but still lit with its old CRTC, "connected"
# with 0x0, or lit outside the (now smaller) screen: those are gone for bspwm (it already
# removes unplugged monitors itself; re-adding them left the right half black).
xr_active() {
  local rs rw=0 rh=0
  rs=$(root_size); [ -n "$rs" ] && read -r rw rh <<<"$rs"
  outputs | awk -F'\t' -v rw="${rw:-0}" -v rh="${rh:-0}" '
    $2 == 1 && $3 != "-" {
      g = $3; split(g, a, /[x+]/)          # W H X Y
      if (a[1] + 0 < 64 || a[2] + 0 < 64) next
      if (rw > 0 && (a[3] + a[1] > rw || a[4] + a[2] > rh)) next
      print $1 "\t" g }'
}

# bspwm's monitors: name <TAB> WxH+X+Y   (from the first "rectangle" of each monitor's tree)
bspwm_rects() {
  ab_has bspc || return 0
  local m r
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    r=$(bspc query -T -m "$m" 2>/dev/null | grep -o '"rectangle":{[^}]*}' | head -n1 |
        sed -E 's/.*"x":(-?[0-9]+),"y":(-?[0-9]+),"width":([0-9]+),"height":([0-9]+).*/\3x\4+\1+\2/')
    [[ $r =~ ^[0-9]+x[0-9]+\+-?[0-9]+\+-?[0-9]+$ ]] || r=-
    printf '%s\t%s\n' "$m" "$r"
  done < <(bspc query -M --names 2>/dev/null)
}

# geometry_plan <xrandr file> <bspwm file>  → actions to make bspwm match xrandr, one per line:
#   geo <name> <WxH+X+Y>   resize / move    add <name> <WxH+X+Y>   new monitor    rm <name>   ghost
# Nothing when xrandr reports no active output (can't tell) — never removes every monitor.
geometry_plan() {
  awk -F'\t' '
    # mirrored outputs (same geometry) are one monitor for bspwm (merge_overlapping_monitors)
    FNR == NR { if ($1 != "" && $2 != "-" && !($2 in seen)) { seen[$2] = 1; xr[$1] = $2; xo[++nx] = $1 }; next }
    $1 != "" { bw[$1] = $2; bo[++nb] = $1 }
    END {
      if (nx == 0 || nb == 0) exit
      for (i = 1; i <= nx; i++) { n = xo[i]
        if (!(n in bw)) print "add " n " " xr[n]
        else if (bw[n] != xr[n]) print "geo " n " " xr[n] }
      for (i = 1; i <= nb; i++) if (!(bo[i] in xr)) print "rm " bo[i]
    }' "$1" "$2"
}

# sync_bspwm: apply geometry_plan with bspc. Ghosts give their desktops to a monitor that stays.
sync_bspwm() {
  ab_has bspc || return 0
  local xf bf act name geo keep d changed=1
  xf=$(mktemp) && bf=$(mktemp) || return 0
  xr_active >"$xf"; bspwm_rects >"$bf"
  keep=$(cut -f1 "$xf" | grep -Fxf - <(cut -f1 "$bf") | head -n1)
  while read -r act name geo; do
    case "$act" in
      geo) bspc monitor "$name" -g "$geo" 2>/dev/null || true ;;
      add) bspc wm -a "$name" "$geo" 2>/dev/null || true ;;
      rm)  [ -n "$keep" ] || keep=$(cut -f1 "$xf" | head -n1)
           [ -n "$keep" ] || continue
           while IFS= read -r d; do
             [ -n "$d" ] && bspc desktop "$d" -m "$keep" 2>/dev/null || true
           done < <(bspc query -D -m "$name" 2>/dev/null)
           bspc monitor "$name" -r 2>/dev/null || true ;;
      *) continue ;;
    esac
    changed=0
  done < <(geometry_plan "$xf" "$bf")
  rm -f "$xf" "$bf"
  return "$changed"
}

# sync until bspwm agrees with xrandr (bspwm may still be digesting VMware's last change):
# up to 3 rounds, 1 s apart. 0 = something was changed.
sync_bspwm_settled() {
  local i rc=1 xf bf
  for i in 1 2 3; do
    sync_bspwm && rc=0
    xf=$(mktemp) && bf=$(mktemp) || return "$rc"
    xr_active >"$xf"; bspwm_rects >"$bf"
    if [ -z "$(geometry_plan "$xf" "$bf")" ]; then rm -f "$xf" "$bf"; return "$rc"; fi
    rm -f "$xf" "$bf"
    [ "${AB_MON_NOSLEEP:-0}" = 1 ] || sleep 1
  done
  return "$rc"
}

repaint_wallpaper() {
  local def="$HOME/.config/bspwm/walls/cherry-field-mountains.jpg"
  if [ -f "$HOME/.fehbg" ]; then sh "$HOME/.fehbg" >/dev/null 2>&1 || true   # feh fills every monitor
  elif [ -f "$def" ] && ab_has feh; then feh --no-fehbg --bg-fill "$def" >/dev/null 2>&1 || true
  fi
}

apply() {
  local bar=1
  [ "${1:-}" = --no-bar ] && bar=0
  apply_xrandr
  sync_bspwm_settled || true
  apply_dpi >/dev/null
  apply_desktops
  [ "$bar" = 1 ] || return 0
  repaint_wallpaper
  if [ -x "$HOME/.config/polybar/launch.sh" ]; then
    setsid -f "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 </dev/null || true
  fi
}

# everything that should trigger a re-apply: every output with its connection and full geometry,
# the root size, RandR 1.5 monitors (VMware may report them differently) and bspwm's view
signature() {
  {
    outputs | cut -f1-3
    xrandr --current 2>/dev/null | sed -n 's/^Screen [0-9]*:.*current \([0-9]* x [0-9]*\).*/root \1/p'
    xrandr --listmonitors 2>/dev/null | tail -n +2
    bspwm_rects
  } | paste -sd' ' -
}

status() {
  local p; p=$(xrandr_policy)
  printf 'virt: %s\nxrandr: %s (%s)\n' "$(virt)" "$(head -n1 <<<"$p")" "$(tail -n1 <<<"$p")"
  echo "== xrandr (activas)"; xr_active
  echo "== bspwm"; bspwm_rects
  local xf bf; xf=$(mktemp); bf=$(mktemp)
  xr_active >"$xf"; bspwm_rects >"$bf"
  echo "== diferencias"; geometry_plan "$xf" "$bf"
  rm -f "$xf" "$bf"
}

watch() {
  ab_has xrandr || exit 0
  exec 9>"$AB_CACHE/monitors-watch.lock"
  if ab_has flock && ! flock -n 9; then exit 0; fi   # already watching
  local last now fails=0
  last=$(signature)
  while :; do
    sleep 2
    pgrep -u "$(id -u)" -x bspwm >/dev/null 2>&1 || exit 0
    if ! now=$(signature) || [ -z "$now" ]; then
      fails=$((fails + 1)); (( fails > 5 )) && exit 0; continue
    fi
    fails=0
    [ "$now" = "$last" ] && continue
    # plugging / VM resizing is noisy (vmware-user sends 2-4 changes in a row when you leave
    # full screen / 2-monitor mode): wait until it is stable for 1 s (max ~8 s), apply once
    local prev=$now i
    for i in 1 2 3 4 5 6 7 8; do
      sleep 1; now=$(signature)
      [ "$now" = "$prev" ] && break
      prev=$now
    done
    apply
    sleep 1
    last=$(signature)
  done
}

case "${1:---apply}" in
  --apply)    apply "${2:-}" ;;
  --watch)    watch ;;
  --dpi)      dpi_for "${2:-}" ;;
  --desktops) apply_desktops ;;
  --list)     outputs ;;
  --status)   status ;;
  --plan)     geometry_plan "${2:?xrandr file}" "${3:?bspwm file}" ;;
  -h|--help)  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "uso: monitors.sh [--apply [--no-bar]|--watch|--dpi [salida]|--desktops|--list|--status]" >&2; exit 2 ;;
esac
