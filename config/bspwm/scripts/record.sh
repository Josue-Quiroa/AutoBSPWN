#!/usr/bin/env bash
# AutoBSPWN v3.4.2 — screen recording (ffmpeg x11grab, video only by default)
#   record.sh --toggle | --start | --stop     Super+Shift+F12 = toggle (own key)
#   record.sh --status        on|off (exit 0 = recording)    record.sh --last   last file saved
#   record.sh --dir           folder in use                  record.sh --set-dir <ruta|default>
#   record.sh --pick-dir      folder chooser (yad --file --directory, else rofi)
#   record.sh --open          open the folder                record.sh --menu   Super+Alt+F12
# Folder (first that is set): $AUTOBSPWN_RECORD_DIR · record_dir= in ~/.config/autobspwn/state ·
# ~/Videos/AutoBSPWN. Files: grabacion-YYYYmmdd-HHMMSS.mkv (never overwritten: -2, -3… and
# ffmpeg -n). It records the monitor you are on (state record_monitor=all = the whole screen).
# Audio only with record_audio=1 (state) or AUTOBSPWN_RECORD_AUDIO=1 (PulseAudio/PipeWire
# "default" source). record_fps=30 by default. With record_with_present=1 the presentation mode
# (Super+F12) starts / stops a recording too.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

PIDF="$AB_CACHE/record.pid"      # pid <TAB> file <TAB> origin (key|present)
LOG="$AB_CACHE/record.log"
DEF_DIR="$HOME/Videos/AutoBSPWN"
FF=${AUTOBSPWN_FFMPEG:-ffmpeg}   # ffmpeg binary (path or name)

expand_dir() {   # ~ / $HOME expansion only (no eval); prints an absolute path or fails
  local d=${1:-}
  d=${d//[$'\r\n']/}
  case "$d" in \~) d=$HOME ;; \~/*) d="$HOME/${d#\~/}" ;; esac
  [[ $d == /* ]] || return 1
  d=${d%/}; printf '%s\n' "${d:-/}"
}

rec_dir() {
  local d
  for d in "${AUTOBSPWN_RECORD_DIR:-}" "$(ab_state_get record_dir)"; do
    [ -n "$d" ] && d=$(expand_dir "$d") && { printf '%s\n' "$d"; return 0; }
  done
  printf '%s\n' "$DEF_DIR"
}

nice_path() { printf '%s\n' "${1/#"$HOME"/\~}"; }

# running: prints "pid<TAB>file<TAB>origin" when an AutoBSPWN ffmpeg is recording
running() {
  local pid file origin
  [ -r "$PIDF" ] || return 1
  IFS=$'\t' read -r pid file origin <"$PIDF" || true
  if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null &&
     tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q 'x11grab'; then
    printf '%s\t%s\t%s\n' "$pid" "$file" "${origin:-key}"; return 0
  fi
  rm -f "$PIDF"; return 1
}

# geometry of the monitor to record: WxH+X+Y
geometry() {
  local g='' m
  m=$(ab_state_get record_monitor focused)
  if [ "$m" != all ] && ab_has bspc; then
    [ "$m" = focused ] || bspc query -M -m "$m" >/dev/null 2>&1 || m=focused
    g=$(bspc query -T -m "$m" 2>/dev/null | grep -o '"rectangle":{[^}]*}' | head -n1 |
        sed -E 's/.*"x":(-?[0-9]+),"y":(-?[0-9]+),"width":([0-9]+),"height":([0-9]+).*/\3x\4+\1+\2/')
  fi
  if ! [[ $g =~ ^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$ ]] && ab_has xrandr; then
    g=$(xrandr --current 2>/dev/null | sed -n 's/^Screen 0:.*current \([0-9]*\) x \([0-9]*\).*/\1x\2+0+0/p' | head -n1)
  fi
  [[ $g =~ ^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$ ]] || return 1
  printf '%s\n' "$g"
}

new_file() {   # new_file <dir> → unused name
  local base f i=2
  base="$1/grabacion-$(date +%Y%m%d-%H%M%S)"
  f="$base.mkv"
  while [ -e "$f" ]; do f="$base-$i.mkv"; i=$((i + 1)); done
  printf '%s\n' "$f"
}

start() {
  local origin=${1:-key} dir g w h x y file pid fps
  local -a audio=()
  if running >/dev/null; then echo "[i] ya se está grabando"; return 0; fi
  if ! ab_has "$FF"; then
    ab_notify "Para grabar instala ffmpeg: sudo apt install ffmpeg" "Grabación"
    echo "[!] ffmpeg no está instalado (sudo apt install ffmpeg)" >&2; return 1
  fi
  [ -n "${DISPLAY:-}" ] || { echo "[!] sin DISPLAY" >&2; return 1; }
  dir=$(rec_dir)
  if ! mkdir -p "$dir" 2>/dev/null || [ ! -w "$dir" ]; then
    ab_notify "No puedo escribir en $(nice_path "$dir") (cámbiala con Super+Alt+F12)" "Grabación"
    echo "[!] carpeta no escribible: $dir" >&2; return 1
  fi
  g=$(geometry) || { echo "[!] no sé qué monitor grabar" >&2; return 1; }
  w=${g%%x*}; h=${g#*x}; h=${h%%+*}; x=${g#*+}; y=${x#*+}; x=${x%%+*}
  w=$(( w / 2 * 2 )); h=$(( h / 2 * 2 ))           # yuv420p needs even sizes
  fps=$(ab_state_get record_fps 30); [[ $fps =~ ^[1-9][0-9]?$ ]] || fps=30
  if [ "${AUTOBSPWN_RECORD_AUDIO:-$(ab_state_get record_audio 0)}" = 1 ]; then
    audio=(-f pulse -i default -c:a aac -b:a 128k)
  fi
  file=$(new_file "$dir")
  setsid "$FF" -hide_banner -loglevel error -nostdin -n \
    -f x11grab -draw_mouse 1 -framerate "$fps" -video_size "${w}x${h}" -i "${DISPLAY}+${x},${y}" \
    "${audio[@]}" -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p "$file" \
    </dev/null >/dev/null 2>"$LOG" &
  pid=$!
  printf '%s\t%s\t%s\n' "$pid" "$file" "$origin" >"$PIDF"
  sleep 0.8
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PIDF"
    ab_notify "ffmpeg no pudo grabar: $(tail -n1 "$LOG" 2>/dev/null)" "Grabación"
    echo "[!] ffmpeg falló (ver $LOG)" >&2; return 1
  fi
  echo "[+] grabando ${w}x${h}+${x}+${y} → $file"
  [ "$origin" = present ] || ab_notify "Grabando la pantalla (${w}x${h}${audio[*]:+, con audio}) → $(nice_path "$file"). Super+Shift+F12 para parar" "Grabación"
}

stop() {   # stop [quiet]  → prints the saved file
  local r pid file origin i size
  r=$(running) || { echo "[i] no hay ninguna grabación en curso"; return 0; }
  IFS=$'\t' read -r pid file origin <<<"$r"
  kill -INT "$pid" 2>/dev/null || true
  for i in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  kill -0 "$pid" 2>/dev/null && { kill -TERM "$pid" 2>/dev/null || true; sleep 0.5; }
  rm -f "$PIDF"
  if [ -s "$file" ]; then
    chmod 600 "$file" 2>/dev/null || true
    ab_state_set last_recording "$file"
    size=$(du -h "$file" 2>/dev/null | cut -f1)
    echo "[+] grabación guardada: $file ($size)"
    [ "${1:-}" = quiet ] || ab_notify "Grabación guardada en $(nice_path "$file") (${size:-?})" "Grabación"
    printf '%s\n' "$file" >"$AB_CACHE/record.last"
  else
    echo "[!] la grabación quedó vacía (ver $LOG)" >&2
    [ "${1:-}" = quiet ] || ab_notify "La grabación quedó vacía (ver $LOG)" "Grabación"
  fi
}

set_dir() {
  local d
  if [ "${1:-}" = default ] || [ -z "${1:-}" ]; then
    ab_state_set record_dir ''; echo "[+] carpeta de grabaciones: $(nice_path "$DEF_DIR") (por defecto)"; return 0
  fi
  d=$(expand_dir "$1") || { echo "[!] usa una ruta absoluta o ~/…" >&2; return 1; }
  mkdir -p "$d" 2>/dev/null && [ -w "$d" ] || { echo "[!] no puedo escribir en $d" >&2; return 1; }
  ab_state_set record_dir "$d"
  echo "[+] carpeta de grabaciones: $d"
  [ -n "${AUTOBSPWN_RECORD_DIR:-}" ] && echo "[i] ojo: AUTOBSPWN_RECORD_DIR=$AUTOBSPWN_RECORD_DIR tiene prioridad" >&2
  return 0
}

pick_dir() {
  local cur d ip
  cur=$(rec_dir)
  if ab_has yad; then
    d=$(yad --file --directory --title "Carpeta para las grabaciones" --filename "$cur/" \
            --width 760 --height 520 2>/dev/null) || return 0
  elif ab_has rofi; then
    ip=$(ab_focus_ip 2>/dev/null || true); ab_is_ipv4 "$ip" || ip=''
    d=$({ printf '%s\n' "$(nice_path "$cur")" "$(nice_path "$DEF_DIR")" "$(nice_path "$HOME/Videos")"
          [ -n "$ip" ] && printf '%s\n' "$(nice_path "$AB_TARGETS/$ip")/evidence"
        } | awk '!s[$0]++' | ab_menu "󰉋 Carpeta" -mesg "Elige una o escribe una ruta (~/… o /…)") || return 0
  else
    ab_notify "Instala yad o rofi (o usa: record.sh --set-dir <ruta>)" "Grabación"; return 1
  fi
  [ -n "$d" ] || return 0
  if set_dir "$d" >/dev/null; then ab_notify "Las grabaciones se guardarán en $(nice_path "$(rec_dir)")" "Grabación"
  else ab_notify "Carpeta no válida o sin permisos: $d" "Grabación"; fi
}

menu() {
  local dir r file opt with p
  dir=$(nice_path "$(rec_dir)")
  if r=$(running); then file=$(cut -f2 <<<"$r"); opt="■ Parar la grabación ($(nice_path "$file"))"
  else opt="● Empezar a grabar (monitor actual, sin audio)"; fi
  with=$(ab_state_get record_with_present 0)
  if ab_present; then p="Modo presentación: ON (Super+F12 para salir)"; else p="Modo presentación: OFF (Super+F12)"; fi
  local -a items=("$opt" "󰉋 Carpeta: $dir — cambiar…" "󰉖 Abrir la carpeta de grabaciones"
                  "↺ Volver a la carpeta por defecto (~/Videos/AutoBSPWN)"
                  "Grabar al activar la presentación: $([ "$with" = 1 ] && echo sí || echo no)" "$p")
  local last; last=$(ab_state_get last_recording)
  [ -n "$last" ] && items+=("󰕧 Última: $(nice_path "$last")")
  local sel
  if ab_has rofi; then
    sel=$(printf '%s\n' "${items[@]}" | ab_menu "󰻃 Grabación" -format i -no-custom \
          -mesg "$(ab_markup_escape "La presentación solo oculta datos; grabar es aparte. Carpeta: $dir")") || return 0
  elif ab_has yad; then
    sel=$(printf '%s\n' "${items[@]}" | yad --list --title "Grabación" --column "Acción" --no-headers \
          --print-column 1 --width 620 --height 320 2>/dev/null) || return 0
    sel=${sel%|}; local i; for i in "${!items[@]}"; do [ "${items[$i]}" = "$sel" ] && { sel=$i; break; }; done
  else
    echo "Carpeta: $dir"; printf '  %s\n' "${items[@]}"; return 0
  fi
  case "$sel" in
    0) if running >/dev/null; then stop; else start key; fi ;;
    1) pick_dir ;;
    2) mkdir -p "$(rec_dir)" 2>/dev/null; ab_files "$(rec_dir)" ;;
    3) set_dir default >/dev/null; ab_notify "Las grabaciones se guardarán en $(nice_path "$DEF_DIR")" "Grabación" ;;
    4) if [ "$with" = 1 ]; then ab_state_set record_with_present 0; ab_notify "Super+F12 ya no graba (solo oculta datos)" "Grabación"
       else ab_state_set record_with_present 1; ab_notify "Super+F12 también grabará la pantalla en $dir" "Grabación"; fi ;;
    5) "$(dirname "$(readlink -f "$0")")/present-mode.sh" --toggle ;;
    6) [ -e "$last" ] && ab_files "$(dirname "$last")" ;;
  esac
  return 0
}

case "${1:---toggle}" in
  --toggle|toggle) if running >/dev/null; then stop; else start key || exit 1; fi ;;
  --start|start)   start "${2:-key}" || exit 1 ;;
  --stop|stop)     stop "${2:-}" ;;
  --status|status) if r=$(running); then echo "on $(cut -f2 <<<"$r")"; exit 0; else echo off; exit 1; fi ;;
  --origin)        r=$(running) && cut -f3 <<<"$r" ;;
  --dir|dir)       rec_dir ;;
  --set-dir)       set_dir "${2:-}" || exit 1 ;;
  --pick-dir)      pick_dir ;;
  --open)          mkdir -p "$(rec_dir)" 2>/dev/null; ab_files "$(rec_dir)" ;;
  --last)          l=$(ab_state_get last_recording); [ -n "$l" ] && echo "$l" ;;
  --menu|menu)     menu ;;
  -h|--help)       sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "uso: record.sh [--toggle|--start|--stop|--status|--last|--dir|--set-dir <ruta|default>|--pick-dir|--open|--menu]" >&2; exit 2 ;;
esac
exit 0
