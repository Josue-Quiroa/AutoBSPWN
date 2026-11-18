#!/usr/bin/env bats
# v3.4.2: desktops of the other monitor, deleting quick notes, screen recording (record.sh +
# presentation mode) and the VMware multi-monitor fix (geometry diff, bspwm sync, VM policy)
# shellcheck disable=SC1090
load test_helper

setup() {
  ab_setup
  D="$REPO/config/bspwm/scripts/desktop.sh"
  M="$REPO/config/bspwm/scripts/monitors.sh"
  QN="$REPO/config/bspwm/scripts/quick-note.sh"
  R="$REPO/config/bspwm/scripts/record.sh"
  PM="$REPO/config/bspwm/scripts/present-mode.sh"
  printf '#!/bin/sh\necho "dunstctl $*" >>"%s/calls.log"\n' "$STUBS" >"$STUBS/dunstctl"; chmod +x "$STUBS/dunstctl"
  export AUTOBSPWN_GUEST_AGENT=''
}

# fake bspc: monitors from $MONS ("eDP-1 HDMI-1"), primary $PRIM, 5 desktops each
fake_bspc() {
  cat >"$STUBS/bspc" <<'BS'
#!/bin/bash
echo "bspc $*" >>"$(dirname "$0")/calls.log"
case "$*" in
  "query -M --names") for m in $MONS; do echo "$m"; done ;;
  "query -M -m primary --names") [ -n "${PRIM:-}" ] && echo "$PRIM" || exit 1 ;;
  "query -D -m "*) for i in 1 2 3 4 5; do echo "0x0$i"; done ;;
  "query -T -m "*) echo '{"name":"x","padding":{"top":0},"rectangle":{"x":1920,"y":0,"width":1281,"height":721},"desktops":[]}' ;;
esac
exit 0
BS
  chmod +x "$STUBS/bspc"
}

# ---------------------------------------------------------------- desktops
@test "Super+Alt+n → n-th desktop of the other monitor (secondary), split and each" {
  fake_bspc
  MONS="eDP-1 HDMI-1" PRIM=eDP-1 run "$D" other-focus 2
  grep -q 'bspc desktop -f HDMI-1:^2$' "$STUBS/calls.log"
  MONS="eDP-1 HDMI-1" PRIM=eDP-1 run "$D" other-send 1
  grep -q 'bspc node -d HDMI-1:^1 --follow$' "$STUBS/calls.log"
  mkdir -p "$HOME/.config/autobspwn"; echo desktops=each >"$HOME/.config/autobspwn/state"
  : >"$STUBS/calls.log"
  MONS="eDP-1 HDMI-1" PRIM=eDP-1 run "$D" other-focus 3
  grep -q 'bspc desktop -f HDMI-1:^3$' "$STUBS/calls.log"
  MONS="eDP-1 HDMI-1" PRIM=eDP-1 run "$D" focus 3                 # Super+3 unchanged
  grep -q 'bspc desktop -f focused:^3$' "$STUBS/calls.log"
}

@test "other monitor rule: next after primary (wraps), no primary = after the first, override" {
  fake_bspc
  [ "$(MONS="A B C" PRIM=B "$D" other)" = C ]
  [ "$(MONS="A B C" PRIM=C "$D" other)" = A ]
  [ "$(MONS="A B C" PRIM='' "$D" other)" = B ]
  mkdir -p "$HOME/.config/autobspwn"; echo second_monitor=C >"$HOME/.config/autobspwn/state"
  [ "$(MONS="A B C" PRIM=A "$D" other)" = C ]
  echo second_monitor=GONE >"$HOME/.config/autobspwn/state"
  [ "$(MONS="A B C" PRIM=A "$D" other)" = B ]
}

@test "one monitor: other-* acts like the normal key; too-high number warns, does nothing" {
  fake_bspc
  MONS="eDP-1" run "$D" other-focus 4
  [ "$status" -eq 0 ]
  grep -q 'bspc desktop -f ^4$' "$STUBS/calls.log"
  [ -z "$(MONS="eDP-1" "$D" other)" ]
  : >"$STUBS/calls.log"
  MONS="eDP-1 HDMI-1" PRIM=eDP-1 run "$D" other-focus 9      # stub: 5 desktops per monitor
  [ "$status" -eq 1 ]
  grep -q 'notify-send' "$STUBS/calls.log"
  run grep -q 'bspc desktop -f' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
  run "$D" other-focus 0
  [ "$status" -eq 2 ]
}

@test "sxhkdrc: other-monitor keys exist and don't clash with existing bindings" {
  grep -q '^super + alt + {1-9,0}$' "$REPO/config/sxhkd/sxhkdrc"
  grep -q '^super + alt + shift + {1-9,0}$' "$REPO/config/sxhkd/sxhkdrc"
  grep -q '^super + shift + F12$' "$REPO/config/sxhkd/sxhkdrc"
  grep -q '^super + alt + F12$' "$REPO/config/sxhkd/sxhkdrc"
  dup=$(grep -E '^[a-z]' "$REPO/config/sxhkd/sxhkdrc" | sed 's/ //g' | sort | uniq -d)
  [ -z "$dup" ]
}

# ---------------------------------------------------------------- notes
@test "note --list / --rm N,M / ranges / out of range; headers kept; timeline without text" {
  focus 10.10.11.5
  for t in uno dos tres cuatro cinco; do "$QN" "secreto-$t" >/dev/null; done
  run "$QN" --list
  [ "${#lines[@]}" -eq 6 ] && [[ "${lines[2]}" == *secreto-dos* ]]
  run "$QN" --rm 2,4
  [ "$status" -eq 0 ]
  f="$AUTOBSPWN_TARGETS/10.10.11.5/notes.md"
  run grep -c 'secreto-' "$f"; [ "$output" = 3 ]
  run grep -q 'secreto-dos\|secreto-cuatro' "$f"
  [ "$status" -ne 0 ]
  grep -q '^## Notas$' "$f" && [ "$(stat -c %a "$f")" = 600 ]
  run "$QN" --rm 1-2
  run grep -c 'secreto-' "$f"; [ "$output" = 1 ]
  run "$QN" --rm 7
  [ "$status" -eq 1 ]
  run "$QN" --rm x
  [ "$status" -eq 1 ]
  grep -q 'borrada' "$AUTOBSPWN_TARGETS/10.10.11.5/timeline.tsv"
  run grep -q 'secreto' "$AUTOBSPWN_TARGETS/10.10.11.5/timeline.tsv"
  [ "$status" -ne 0 ]
}

@test "note --rm-all needs --yes without a terminal; hand-written lines survive" {
  "$QN" a >/dev/null; "$QN" b >/dev/null
  echo "texto mío a mano" >>"$HOME/notes/inbox.md"
  run "$QN" --rm-all </dev/null
  [ "$status" -eq 1 ]
  run grep -c '^- \[' "$HOME/notes/inbox.md"; [ "$output" = 2 ]
  run "$QN" --rm-all --yes
  [ "$status" -eq 0 ]
  run grep -c '^- \[' "$HOME/notes/inbox.md"; [ "$output" = 0 ]
  grep -q 'texto mío a mano' "$HOME/notes/inbox.md"
  run "$REPO/scripts/note" --list
  [[ "$output" == *"sin notas"* ]]
}

@test "popup: Alt+d (rofi exit 10) opens the manager; multi-select + confirm deletes" {
  "$QN" uno >/dev/null; "$QN" dos >/dev/null; "$QN" tres >/dev/null
  # 1st rofi = note popup → Alt+d; 2nd = manager → rows 1 and 3; 3rd = confirm → "Sí" (index 1)
  cat >"$STUBS/rofi" <<'RF'
#!/bin/bash
cat >/dev/null
c="$(dirname "$0")/rofi.n"; n=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$c"
case "$n" in 1) exit 10 ;; 2) printf '1\n3\n' ;; 3) echo 1 ;; esac
RF
  chmod +x "$STUBS/rofi"
  run "$QN"
  [ "$status" -eq 0 ]
  run grep -c '^- \[' "$HOME/notes/inbox.md"; [ "$output" = 1 ]
  grep -q '\] dos$' "$HOME/notes/inbox.md"
}

@test "manager: 'delete all' row needs BORRAR typed; a wrong word deletes nothing" {
  "$QN" uno >/dev/null; "$QN" dos >/dev/null
  printf '#!/bin/bash\ncat >/dev/null\nc="$(dirname "$0")/rofi.n"; n=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$c"\ncase "$n" in 1) echo 0 ;; 2) echo borrar ;; 3) echo 0 ;; 4) echo BORRAR ;; esac\n' >"$STUBS/rofi"
  chmod +x "$STUBS/rofi"
  run "$QN" --manage
  run grep -c '^- \[' "$HOME/notes/inbox.md"; [ "$output" = 2 ]
  run "$QN" --manage
  run grep -c '^- \[' "$HOME/notes/inbox.md"; [ "$output" = 0 ]
}

# ---------------------------------------------------------------- recording
fake_ffmpeg() {
  cat >"$STUBS/ffmpeg" <<'FF'
#!/bin/bash
echo "ffmpeg $*" >>"$(dirname "$0")/calls.log"
out=${!#}
[ -e "$out" ] && exit 1
trap 'echo video >"$out"; exit 0' INT TERM
while :; do sleep 0.1; done
FF
  chmod +x "$STUBS/ffmpeg"
  printf '#!/bin/sh\nexec "$@"\n' >"$STUBS/setsid"; chmod +x "$STUBS/setsid"
  export DISPLAY=:9
}

@test "record: folder default / state / env; set-dir validates; ~ expanded" {
  [ "$("$R" --dir)" = "$HOME/Videos/AutoBSPWN" ]
  # shellcheck disable=SC2088  # a literal ~ on purpose: record.sh expands it
  run "$R" --set-dir '~/clases'
  [ "$status" -eq 0 ] && [ "$("$R" --dir)" = "$HOME/clases" ] && [ -d "$HOME/clases" ]
  grep -qx "record_dir=$HOME/clases" "$HOME/.config/autobspwn/state"
  [ "$(AUTOBSPWN_RECORD_DIR=/tmp/otra "$R" --dir)" = /tmp/otra ]
  run "$R" --set-dir relativa/x
  [ "$status" -eq 1 ]
  run "$R" --set-dir default
  [ "$("$R" --dir)" = "$HOME/Videos/AutoBSPWN" ]
}

@test "record: focused monitor geometry (even size), no audio, dated name, never overwrites" {
  fake_bspc; fake_ffmpeg
  run "$R" --start
  [ "$status" -eq 0 ]
  grep -q -- '-video_size 1280x720 -i :9+1920,0' "$STUBS/calls.log"
  run grep -q -- '-f pulse' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
  run "$R" --status
  [ "$status" -eq 0 ] && [[ "$output" == on* ]]
  f=$(cut -d' ' -f2- <<<"$output")
  [[ "$f" =~ /Videos/AutoBSPWN/grabacion-[0-9]{8}-[0-9]{6}(-[0-9]+)?\.mkv$ ]]
  run "$R" --stop
  [ "$status" -eq 0 ] && [[ "$output" == *"grabación guardada: $f"* ]]
  grep -q "Grabación guardada en" "$STUBS/calls.log"
  [ -s "$f" ] && [ "$(stat -c %a "$f")" = 600 ]
  [ "$("$R" --last)" = "$f" ]
  run "$R" --status
  [ "$status" -eq 1 ]
  # same second → -2 suffix, the first file is untouched
  run "$R" --start; run "$R" --start          # 2nd start while recording = no-op
  run "$R" --stop
  [ "$(find "$HOME/Videos/AutoBSPWN" -name 'grabacion-*.mkv' | wc -l)" -eq 2 ]
  [ "$(cat "$f")" = video ]
}

@test "record: audio only when asked; no ffmpeg = clear warning" {
  fake_bspc; fake_ffmpeg
  AUTOBSPWN_RECORD_AUDIO=1 run "$R" --start
  grep -q -- '-f pulse -i default' "$STUBS/calls.log"
  run "$R" --stop
  AUTOBSPWN_FFMPEG=ffmpeg-no-instalado run "$R" --start
  [ "$status" -eq 1 ] && [[ "$output" == *"apt install ffmpeg"* ]]
}

@test "presentation: says it does NOT record; with record_with_present=1 it records and reports the file" {
  fake_bspc; fake_ffmpeg
  run "$PM" --on
  [[ "$output" == *"NO graba"* ]] && [[ "$output" == *"Videos/AutoBSPWN"* ]]
  run "$R" --status
  [ "$status" -eq 1 ]
  "$PM" --off >/dev/null
  . "$AB_LIB"; ab_state_set record_with_present 1
  run "$PM" --on
  [[ "$output" == *"Grabando la pantalla"* ]]
  run "$PM" --bar
  [[ "$output" == *OCULTO* ]] && [[ "$output" == *REC* ]]
  run "$PM" --off
  [[ "$output" == *"Grabación guardada en ~/Videos/AutoBSPWN/grabacion-"* ]]
  run "$R" --status
  [ "$status" -eq 1 ]
  # a recording started with its own key is not stopped by the presentation mode
  "$PM" --on >/dev/null; "$R" --stop >/dev/null
  "$R" --start >/dev/null; "$PM" --off >/dev/null
  run "$R" --status
  [ "$status" -eq 0 ]
  "$R" --stop >/dev/null
}

# ---------------------------------------------------------------- monitors / VMware
@test "geometry plan: resize, add, ghost removal, mirrored outputs, nothing when unsure" {
  x="$BATS_TEST_TMPDIR/x"; b="$BATS_TEST_TMPDIR/b"
  printf 'Virtual-1\t1920x1080+0+0\nVirtual-2\t1920x1080+1920+0\n' >"$x"
  printf 'Virtual-1\t3840x1080+0+0\n' >"$b"                       # VMware: one big monitor
  run "$M" --plan "$x" "$b"
  [ "${lines[0]}" = "geo Virtual-1 1920x1080+0+0" ] && [ "${lines[1]}" = "add Virtual-2 1920x1080+1920+0" ]
  printf 'Virtual-1\t1920x1080+0+0\nVirtual-2\t1920x1080+1920+0\nVirtual-3\t800x600+3840+0\n' >"$b"
  run "$M" --plan "$x" "$b"
  [ "$output" = "rm Virtual-3" ]
  printf 'Virtual-1\t1920x1080+0+0\nVirtual-2\t1920x1080+1920+0\n' >"$b"
  run "$M" --plan "$x" "$b"
  [ -z "$output" ]
  printf 'eDP-1\t1920x1080+0+0\nHDMI-1\t1920x1080+0+0\n' >"$x"        # mirror = one monitor
  printf 'eDP-1\t1920x1080+0+0\n' >"$b"
  run "$M" --plan "$x" "$b"
  [ -z "$output" ]
  : >"$x"; run "$M" --plan "$x" "$b"; [ -z "$output" ]               # xrandr says nothing
  printf 'eDP-1\t1920x1080+0+0\n' >"$x"; : >"$b"
  run "$M" --plan "$x" "$b"; [ -z "$output" ]                        # bspwm not answering
}

@test "VMware / VirtualBox guests: xrandr is left to the VM agent (xrandr=on forces it)" {
  cat >"$STUBS/xrandr" <<XR
#!/bin/sh
case "\$*" in *--output*) echo "xrandr \$*" >>"$STUBS/calls.log"; exit 0 ;; esac
cat <<'OUT'
Screen 0: minimum 1 x 1, current 3840 x 1080, maximum 8192 x 8192
Virtual-1 connected primary 1920x1080+0+0 0mm x 0mm
Virtual-2 connected (normal left inverted right x axis y axis) 0mm x 0mm
OUT
XR
  chmod +x "$STUBS/xrandr"
  AUTOBSPWN_GUEST_AGENT=vmware-user run "$M" --status
  [[ "$output" == *"xrandr: off (auto: lo gestiona vmware-user"* ]]
  AUTOBSPWN_GUEST_AGENT=vmware-user DISPLAY=:9 run "$M" --apply --no-bar
  run grep -q 'xrandr --output' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
  unset AUTOBSPWN_GUEST_AGENT
  AUTOBSPWN_VIRT=vmware run "$M" --status                          # agent not started yet
  [[ "$output" == *"xrandr: off"* ]]
  . "$AB_LIB"; ab_state_set xrandr on
  AUTOBSPWN_GUEST_AGENT=vmware-user DISPLAY=:9 run "$M" --apply --no-bar
  grep -q 'xrandr --output Virtual-2 --auto --right-of Virtual-1' "$STUBS/calls.log"
}

@test "sync: bspwm monitors are fixed to match xrandr (resize, add, ghost desktops moved first)" {
  cat >"$STUBS/xrandr" <<XR
#!/bin/sh
case "\$*" in *--output*) exit 0 ;; esac
cat <<'OUT'
Screen 0: minimum 1 x 1, current 3840 x 1080, maximum 8192 x 8192
Virtual-1 connected primary 1920x1080+0+0 0mm x 0mm
Virtual-2 connected 1920x1080+1920+0 0mm x 0mm
OUT
XR
  chmod +x "$STUBS/xrandr"
  cat >"$STUBS/bspc" <<'BS'
#!/bin/bash
echo "bspc $*" >>"$(dirname "$0")/calls.log"
case "$*" in
  "query -M --names") printf 'Virtual-1\nghost\n' ;;
  "query -T -m Virtual-1") echo '{"rectangle":{"x":0,"y":0,"width":3840,"height":1080}}' ;;
  "query -T -m ghost") echo '{"rectangle":{"x":5000,"y":0,"width":800,"height":600}}' ;;
  "query -D -m ghost") echo 0xAA ;;
esac
exit 0
BS
  chmod +x "$STUBS/bspc"
  AUTOBSPWN_GUEST_AGENT=vmware-user DISPLAY=:9 run "$M" --apply --no-bar
  grep -q 'bspc monitor Virtual-1 -g 1920x1080+0+0' "$STUBS/calls.log"
  grep -q 'bspc wm -a Virtual-2 1920x1080+1920+0' "$STUBS/calls.log"
  grep -q 'bspc desktop 0xAA -m Virtual-1' "$STUBS/calls.log"
  grep -q 'bspc monitor ghost -r' "$STUBS/calls.log"
  [ "$(grep -n 'desktop 0xAA -m' "$STUBS/calls.log" | head -n1 | cut -d: -f1)" -lt "$(grep -n 'monitor ghost -r' "$STUBS/calls.log" | head -n1 | cut -d: -f1)" ]
}

@test "watch signature changes with geometry only (same names, new resolution / position)" {
  printf '#!/bin/sh\ncat "%s/xr.out"\n' "$STUBS" >"$STUBS/xrandr"; chmod +x "$STUBS/xrandr"
  printf 'Screen 0: minimum 1 x 1, current 3840 x 1080, maximum 8192 x 8192\nVirtual-1 connected primary 1920x1080+0+0 0mm x 0mm\nVirtual-2 connected 1920x1080+1920+0 0mm x 0mm\n' >"$STUBS/xr.out"
  . "$AB_LIB"
  sig() { bash -c '. "$1"; eval "$(sed -n "/^outputs()/,/^}/p;/^xr_active()/,/^}/p;/^bspwm_rects()/,/^}/p;/^signature()/,/^}/p" "$2")"; signature' _ "$AB_LIB" "$M"; }
  a=$(sig)
  sed -i 's/1920x1080+1920+0/2560x1440+1920+0/' "$STUBS/xr.out"
  b=$(sig)
  [ "$a" != "$b" ]
  sed -i 's/2560x1440+1920+0/2560x1440+0+1080/' "$STUBS/xr.out"
  [ "$(sig)" != "$b" ]
}
