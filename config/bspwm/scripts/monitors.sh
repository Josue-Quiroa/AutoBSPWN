#!/usr/bin/env bash
# AutoBSPWN v3.4.7 — HiDPI + multi-monitor (automatic; bspwmrc runs it)
#   monitors.sh [--apply]        new outputs on / unplugged off (xrandr, see policy), bspwm monitors
#                                synced with xrandr, Xft.dpi + rofi DPI, desktops split across the
#                                monitors, wallpaper repainted, one polybar per monitor
#   monitors.sh --apply --no-bar   same without relaunching polybar / wallpaper (bspwmrc does it)
#   monitors.sh --watch          follow plug / unplug / resolution changes (one instance; polls
#                                every 2 s, applies once the layout is stable for 1 s)
#   monitors.sh --dpi [OUTPUT]   DPI for that output (default: primary)   --list   outputs
#   monitors.sh --status         xrandr policy, outputs and bspwm monitors (diagnostics)
#   monitors.sh --fix            "Reparar pantallas" (Super+Alt+Shift+r): forced mode kick + layout
#   monitors.sh --layout         the kick / layout it would apply (VMware/VirtualBox, see below)
# DPI: physical size from xrandr → 96/120/144/168/192 (VMs report 0 mm → 96, or 192 when the
# screen is 3200+ px wide). Force it in ~/.config/autobspwn/state with dpi=144 (dpi=auto = default).
# Desktops (state: desktops=split, default): I–X split in order (2 monitors: I–V / VI–X);
# desktops=each keeps I–X on every monitor (the pre-3.4 layout).
# Revivir (state revive=1, default; AUTOBSPWN_REVIVE=0 lo apaga): en --fix, una salida VMware/VBox
# desconectada pero con modos válidos se vuelve a encender con --right-of en vez de apagarse; el
# límite del root la descarta si de verdad ya no está.
# xrandr policy (state xrandr=auto|on|off): auto (default) turns new outputs on / unplugged ones
# off, EXCEPT in VMware / VirtualBox / SPICE guests where open-vm-tools (vmware-user), VBoxClient
# or spice-vdagent own the layout: there we only react to what they set. on = always, off = never.
# v3.4.2: changes are detected by full geometry (size + position of every output, root size,
# RandR monitors and bspwm's monitors), not only by name; bspwm's monitors are re-synced with
# xrandr when they disagree (resize / add / remove ghosts), then desktops, wallpaper and bars.
# v3.4.7: --fix revivea de verdad (REVIVE se fija antes del plan); el plan puede añadir monitores
# a un bspwm sin monitores; escritorios repartidos por posición real (izq→der); $AB_CACHE se crea
# si falta (sin él el lock abortaba en silencio); --fix devuelve estado real; kick sólo se marca
# como hecho si xrandr aceptó el layout.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

ROFI_DPI="$HOME/.config/rofi/dpi.rasi"

# v3.4.6: en VMware una salida recien devuelta sigue reportandose "disconnected" con el CRTC
# vivo y modos validos. Por eso funcionaba el comando a mano y --fix no: el plan la tiraba por
# desconectada y luego le hacia `xrandr --output Virtual-2 --off`. Se revive solo en --fix.
# revive=0 en el state (o AUTOBSPWN_REVIVE=0) recupera el comportamiento 3.4.5.
revive_on() { [ "${AUTOBSPWN_REVIVE:-$(ab_state_get revive 1)}" != 0 ]; }

# v3.4.7: una sola regex para las salidas revivibles (la usan revivable y xr_active)
REVIVABLE_RE='^(Virtual|VMware|vbox|VGA-)'
revivable() { [[ $1 =~ $REVIVABLE_RE ]]; }

# name  connected 0|1  geometry WxH+X+Y or -  width mm  primary 0|1
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
       else printf 'on\nauto: sin agente de VM\n'; fi
  esac
}

apply_xrandr() {
  ab_has xrandr || return 0
  [ "$(xrandr_policy | head -n1)" = off ] && return 0
  local name conn geo mm prim last='' lastx=-1 x w changed=0
  local -a on=() off=()
  while IFS=$'\t' read -r name conn geo mm prim; do
    if [ "$geo" != - ]; then
      if [ "$conn" = 0 ]; then
        [ "${REVIVE:-0}" = 1 ] && revivable "$name" && continue
        off+=("$name"); continue
      fi
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
  # v3.4.7: de izquierda a derecha por geometría real, no por orden de nombre de bspwm
  mapfile -t mons < <(bspwm_rects |
    awk -F'\t' 'NF { split($2, a, /[x+]/); print (a[3] + 0) "\t" $1 }' |
    sort -n -k1,1 | cut -f2 | grep -v '^$')
  [ ${#mons[@]} -gt 0 ] || mapfile -t mons < <(bspc query -M --names 2>/dev/null)
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
    [ -n "${sets[$i]:-}" ] || continue   # sin juego asignado: no tocar el monitor
    cur=$(bspc query -D -m "${mons[$i]}" --names 2>/dev/null | paste -sd' ' -)
    [ "$cur" = "${sets[$i]}" ] && continue
    # shellcheck disable=SC2086  # one word per desktop name
    bspc monitor "${mons[$i]}" -d ${sets[$i]} 2>/dev/null || true
  done
}

# active xrandr outputs: name  WxH+X+Y   (connected or not: what is really lit)
# root (screen) size: "W H" or nothing
root_size() {
  xrandr --current 2>/dev/null | sed -n 's/^Screen [0-9]*:.*current \([0-9]*\) x \([0-9]*\).*/\1 \2/p' | head -n1
}

# active xrandr outputs that bspwm should have: name  WxH+X+Y
# v3.4.3: only CONNECTED outputs with a real mode. VMware, when you leave the 2-monitor / full
# screen mode, may leave Virtual-2 "disconnected" but still lit with its old CRTC, "connected"
# with 0x0, or lit outside the (now smaller) screen: those are gone for bspwm (it already
# removes unplugged monitors itself; re-adding them left the right half black).
# v3.4.6: on a forced --fix a disconnected VMware/VBox output is revived (see revive_on); the
# root bound still drops it when it really is gone.
xr_active() {
  local rs rw=0 rh=0 rev=0
  [ "${REVIVE:-0}" = 1 ] && rev=1
  rs=$(root_size); [ -n "$rs" ] && read -r rw rh <<<"$rs"
  outputs | awk -F'\t' -v rw="${rw:-0}" -v rh="${rh:-0}" -v rev="$rev" -v re="$REVIVABLE_RE" '
    $3 != "-" && ($2 == 1 || (rev == 1 && $1 ~ re)) {
      g = $3; split(g, a, /[x+]/)          # W H X Y
      if (a[1] + 0 < 64 || a[2] + 0 < 64) next
      if (rw > 0 && (a[3] + a[1] > rw || a[4] + a[2] > rh)) next
      print $1 "\t" g }'
}

# bspwm's monitors: name  WxH+X+Y   (from the first "rectangle" of each monitor's tree)
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

# geometry_plan    → actions to make bspwm match xrandr, one per line:
#   geo     resize / move    add     new monitor    rm    ghost
# Nothing when xrandr reports no active output (can't tell) — never removes every monitor.
geometry_plan() {
  awk -F'\t' '
    # mirrored outputs (same geometry) are one monitor for bspwm (merge_overlapping_monitors)
    FNR == NR { if ($1 != "" && $2 != "-" && !($2 in seen)) { seen[$2] = 1; xr[$1] = $2; xo[++nx] = $1 }; next }
    $1 != "" { bw[$1] = $2; bo[++nb] = $1 }
    END {
      if (nx == 0) exit
      # v3.4.7: nb == 0 ya no aborta; un bspwm sin monitores necesita los "add"
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

# ---------------------------------------------------------------- v3.4.4 VM "kick"
# VMware (and VirtualBox) only really switch the guest between 1 and 2 screens, or back to the
# native size after leaving full screen, when the MODE CHANGES: re-applying the same mode is
# ignored, so the second screen stays black / half drawn although xrandr and bspwm agree.
# Kick = primary output to another existing mode (1600x900, 1280x720 or any other), wait 1 s,
# then the target layout: every connected output at its target mode, the primary at 0,0 with
# --primary and the rest --right-of in order. Never `bspc wm -r` (it re-runs bspwmrc: loop).
# Target mode: res=WxH (state) or AUTOBSPWN_RES, else the output's preferred mode (+), else
# 1920x1080, else its first mode. vm_kick=off (state) disables it; xrandr=off too.

SLEEP() { [ "${AB_MON_NOSLEEP:-0}" = 1 ] || sleep "$1"; }

# modes: name  connected 0|1  geometry|-  primary 0|1  preferred|-  m1,m2,…
modes_table() {
  ab_has xrandr || return 0
  xrandr --query 2>/dev/null | awk '
    function flush() { if (name != "") print name "\t" conn "\t" geo "\t" prim "\t" pref "\t" ml }
    /^[^ \t]+ (connected|disconnected)/ {
      flush(); name = $1; conn = ($2 == "connected") ? 1 : 0; geo = "-"; prim = 0; pref = "-"; ml = ""
      for (i = 3; i <= NF; i++) {
        if ($i == "primary") prim = 1
        else if (geo == "-" && $i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) geo = $i
      }
      next }
    /^[ \t]+[0-9]+x[0-9]+/ && name != "" {
      m = $1; ml = ml (ml == "" ? "" : ",") m
      for (i = 2; i <= NF; i++) if (index($i, "+") && pref == "-") pref = m
      next }
    END { flush() }'
}

in_vm() {
  case "$(guest_agent)" in vmware*|VBox*|virtualbox*) return 0 ;; esac
  case "$(virt)" in vmware|oracle) return 0 ;; esac
  # Virtual-1/Virtual-2 es el driver de VMware/VBox: kick aunque no se detecte el agente
  ab_has xrandr && xrandr --query 2>/dev/null |
    grep -qE '^(Virtual-?[0-9]+|vboxvideo) (connected|disconnected)' && return 0
  return 1
}

kick_enabled() {
  [ "${1:-}" != force ] && [ "$(ab_state_get vm_kick auto)" = off ] && return 1
  [ "$(ab_state_get xrandr auto)" = off ] && return 1
  ab_has xrandr
}

# target_mode
target_mode() {
  local pref=$1 list=",$2," want=${AUTOBSPWN_RES:-}
  [ -n "$want" ] || want=$(ab_state_get res auto)
  if [[ $want =~ ^[0-9]+x[0-9]+$ ]] && [[ $list == *",$want,"* ]]; then echo "$want"; return 0; fi
  if [ "$pref" != - ]; then echo "$pref"; return 0; fi
  if [[ $list == *",1920x1080,"* ]]; then echo 1920x1080; return 0; fi
  list=${list#,}; echo "${list%%,*}"
}

# intermediate_mode → another existing mode, or nothing
intermediate_mode() {
  local target=$1 cur=$2 m
  local -a all
  IFS=, read -r -a all <<<"$3"
  for m in 1600x900 1280x720 "${all[@]}"; do
    [ -n "$m" ] && [ "$m" != "$target" ] && [ "$m" != "$cur" ] || continue
    [[ ",$3," == *",$m,"* ]] && { echo "$m"; return 0; }
  done
  for m in "${all[@]}"; do [ "$m" != "$target" ] && { echo "$m"; return 0; }; done
  return 1
}

# layout_plan → lines: primary · right · off (lit but disconnected) · want (expected result)
layout_plan() {
  local f=$1 name conn geo prim pref ml first='' x=0 mode cur inter
  local -a order=() revived=()
  local rev=0 seenprim=0
  [ "${REVIVE:-0}" = 1 ] && rev=1
  # primary first (the xrandr primary if connected, else the first connected output)
  while IFS=$'\t' read -r name conn geo prim pref ml; do
    [ -n "$ml" ] || continue
    if [ "$conn" != 1 ]; then
      (( rev )) && revivable "$name" || continue
      revived+=("$name")
    fi
    if [ "$prim" = 1 ] && (( ! seenprim )); then order=("$name" "${order[@]}"); seenprim=1
    else order+=("$name"); fi
  done <"$f"
  [ ${#order[@]} -gt 0 ] || return 0
  for first in "${order[@]}"; do
    IFS=$'\t' read -r name conn geo prim pref ml < <(awk -F'\t' -v n="$first" '$1 == n' "$f")
    mode=$(target_mode "$pref" "$ml")
    if [ "$first" = "${order[0]}" ]; then
      cur=-; [ "$geo" != - ] && cur=${geo%%+*}
      inter=$(intermediate_mode "$mode" "$cur" "$ml") || inter=-
      echo "primary $name $mode $inter"
    else
      echo "right $name $mode"
    fi
    echo "want $name $mode+$x+0"
    x=$(( x + ${mode%%x*} ))
  done
  # off: encendidas pero desconectadas y NO revividas
  awk -F'\t' '$2 == 0 && $3 != "-" { print "off " $1 }' "$f" |
    { if [ ${#revived[@]} -gt 0 ]; then grep -vxFf <(printf 'off %s\n' "${revived[@]}") || true; else cat; fi; }
}

# layout_ok → 0 when every output already has its target geometry
layout_ok() {
  local f=$1 plan=$2 name w
  ! grep -q '^off ' <<<"$plan" || return 1
  while read -r _ name w; do
    [ "$(awk -F'\t' -v n="$name" '$1 == n { print $3 }' "$f")" = "$w" ] || return 1
  done < <(grep '^want ' <<<"$plan")
  return 0
}

KICK_LAST="$AB_CACHE/monitors-kick.last"

# maybe_kick [force] → 0 when a kick was done
maybe_kick() {
  local force=${1:-} f plan key prev
  kick_enabled "$force" || return 1
  [ "$force" = force ] || in_vm || return 1
  f=$(mktemp) || return 1
  # v3.4.7: REVIVE ANTES del plan, o layout_plan manda la salida a "off" en vez de revivirla
  if [ "$force" = force ] && revive_on; then REVIVE=1; fi
  modes_table >"$f"
  plan=$(layout_plan "$f")
  if ! grep -q '^primary ' <<<"$plan"; then rm -f "$f"; return 1; fi
  if [ "$force" != force ] && layout_ok "$f" "$plan"; then rm -f "$f"; return 1; fi
  # once per transition: same connected outputs + same starting layout = already kicked
  key="$(awk -F'\t' '$2 == 1 { printf "%s ", $1 }' "$f")| $(awk -F'\t' '$3 != "-" { printf "%s=%s ", $1, $3 }' "$f")"
  prev=$(cat "$KICK_LAST" 2>/dev/null || true)
  rm -f "$f"
  if [ "$force" != force ] && [ "$key" = "$prev" ]; then return 1; fi
  # v3.4.7: la marca sólo se escribe si xrandr aceptó el layout (si no, el dedupe bloquea el reintento)
  run_kick "$plan" || return 1
  printf '%s\n' "$key" >"$KICK_LAST"
  return 0
}

run_kick() {
  local plan=$1 act name mode inter prev=''
  local -a cmd=()
  read -r act name mode inter < <(grep '^primary ' <<<"$plan")
  if [ "$inter" != - ]; then
    xrandr --output "$name" --mode "$inter" 2>/dev/null || true
    SLEEP 1
  fi
  cmd=(--output "$name" --mode "$mode" --pos 0x0 --primary); prev=$name
  while read -r act name mode; do
    case "$act" in
      right) cmd+=(--output "$name" --mode "$mode" --right-of "$prev"); prev=$name ;;
      off)   cmd+=(--output "$name" --off) ;;
    esac
  done < <(grep -E '^(right|off) ' <<<"$plan")
  xrandr "${cmd[@]}" 2>/dev/null || return 1
  SLEEP 1
  return 0
}

APPLY_STAMP="$AB_CACHE/monitors-applied"

apply() {
  local bar=1 kick=auto a rc=0
  REVIVE=0
  for a; do
    case "$a" in --no-bar) bar=0 ;; --fix) kick=force ;; --no-kick) kick=no ;; esac
  done
  mkdir -p "$AB_CACHE" 2>/dev/null || true   # sin el dir, el exec del lock falla y todo se salta
  # one apply at a time (watcher, Super+Alt+Shift+r / --fix, bspwmrc)
  exec 8>"$AB_CACHE/monitors-apply.lock"
  if ab_has flock && ! flock -w "${AB_MON_LOCK_WAIT:-20}" 8; then
    echo "[i] monitors.sh: otro ajuste en curso, me salto este" >&2
    exec 8>&-; return 1
  fi
  if [ "$kick" = force ]; then maybe_kick force || rc=1
  elif [ "$kick" = auto ]; then maybe_kick || true; fi
  apply_xrandr
  sync_bspwm_settled || true
  apply_dpi >/dev/null
  apply_desktops
  date +%s >"$APPLY_STAMP"
  # sxhkd may lose its key grabs after a screen change: reload it (SIGUSR1 = re-read + re-grab)
  pkill -USR1 -u "$(id -u)" -x sxhkd 2>/dev/null || true
  if [ "$bar" = 1 ]; then
    repaint_wallpaper
    if [ -x "$HOME/.config/polybar/launch.sh" ]; then
      setsid -f "$HOME/.config/polybar/launch.sh" </dev/null >/dev/null 2>&1 8>&- 9>&-
    fi
  fi
  exec 8>&-
  return "$rc"
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
  if in_vm && kick_enabled; then echo "kick de modo (VM): sí (vm_kick=off para desactivarlo)"; else echo "kick de modo (VM): no"; fi
  echo "revivir desconectadas en --fix: $(revive_on && echo sí || echo no)"
  echo "== xrandr (activas)"; xr_active
  echo "== bspwm"; bspwm_rects
  local xf bf; xf=$(mktemp); bf=$(mktemp)
  xr_active >"$xf"; bspwm_rects >"$bf"
  echo "== diferencias"; geometry_plan "$xf" "$bf"
  rm -f "$xf" "$bf"
}

WATCH_PID="$AB_CACHE/monitors-watch.pid"

# recent_apply → 0 when any apply finished less than $AB_MON_SUPPRESS (4) seconds ago
recent_apply() {
  local t now
  t=$(cat "$APPLY_STAMP" 2>/dev/null) || return 1
  [[ $t =~ ^[0-9]+$ ]] || return 1
  now=$(date +%s)
  (( now - t < ${AB_MON_SUPPRESS:-4} ))
}

watch() {
  ab_has xrandr || exit 0
  local old
  # one watcher: a bspwm reload re-runs bspwmrc → the old watcher is replaced by the new one
  old=$(cat "$WATCH_PID" 2>/dev/null || true)
  if [[ $old =~ ^[0-9]+$ ]] && [ "$old" != $$ ] && kill -0 "$old" 2>/dev/null &&
     [ -r "/proc/$old/cmdline" ] &&
     tr '\0' ' ' <"/proc/$old/cmdline" 2>/dev/null | grep -q 'monitors.sh --watch'; then
    kill "$old" 2>/dev/null || true
  fi
  mkdir -p "$AB_CACHE" 2>/dev/null || true
  exec 9>"$AB_CACHE/monitors-watch.lock"
  if ab_has flock && ! flock -w 3 9; then exit 0; fi   # another one still holds it
  echo $$ >"$WATCH_PID"
  local last now fails=0 prev i
  last=$(signature)
  while :; do
    SLEEP 2
    pgrep -u "$(id -u)" -x bspwm >/dev/null 2>&1 || exit 0
    if ! now=$(signature) || [ -z "$now" ]; then
      fails=$((fails + 1)); (( fails > 5 )) && exit 0; continue
    fi
    fails=0
    [ "$now" = "$last" ] && continue
    # our own changes (kick, Super+Alt+Shift+r, bspwmrc) fire events too: ignore them for 4 s
    if recent_apply; then last=$now; continue; fi
    # VMware sends 2-4 changes in a row when you switch 1 ↔ 2 screens or leave full screen:
    # wait until the layout is stable for 1 s (max ~8 s), then apply once
    prev=$now
    for i in 1 2 3 4 5 6 7 8; do
      SLEEP 1; now=$(signature)
      [ "$now" = "$prev" ] && break
      prev=$now
    done
    apply
    SLEEP "${AB_MON_SUPPRESS:-4}"            # suppression window: the kick's own events
    last=$(signature)
    [ "${AB_MON_WATCH_ONCE:-0}" = 1 ] && exit 0   # tests
  done
}

case "${1:---apply}" in
  --apply)    [ $# -gt 0 ] && shift; apply "$@" ;;
  --fix)      if apply --fix; then echo "[+] pantallas reparadas (cambio de modo + layout)"
              else echo "[!] no aplicado: otro ajuste en curso o xrandr falló"; fi ;;
  --layout)   REVIVE=1; f=$(mktemp); modes_table >"$f"; layout_plan "$f"; rm -f "$f" ;;
  --watch)    watch ;;
  --dpi)      dpi_for "${2:-}" ;;
  --desktops) apply_desktops ;;
  --list)     outputs ;;
  --status)   status ;;
  --plan)     geometry_plan "${2:?xrandr file}" "${3:?bspwm file}" ;;
  -h|--help)  sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "uso: monitors.sh [--apply [--no-bar] [--no-kick]|--fix|--layout|--watch|--dpi [salida]|--desktops|--list|--status]" >&2; exit 2 ;;
esac
