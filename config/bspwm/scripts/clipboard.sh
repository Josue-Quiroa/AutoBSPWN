#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — clipboard history (rofi)
# Backends, first found wins (only ONE daemon is ever started):
#   1. greenclip  static binary from GitHub (Install.sh → ~/.local/bin), native rofi mode
#   2. copyq      Debian/Parrot/Kali package, used when greenclip can't be downloaded
#   3. clipmenu   only if the user installed it by hand (not packaged in Parrot/Kali)
#   clipboard.sh            open history; Enter copies the entry back to the clipboard
#   clipboard.sh --clear    wipe history
#   clipboard.sh --daemon   start the backend daemon if it is not running (bspwmrc)
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"

backend() {
  if ab_has greenclip; then echo greenclip
  elif ab_has copyq; then echo copyq
  elif ab_has clipmenu && ab_has clipmenud; then echo clipmenu
  else echo none
  fi
}

running() { pgrep -u "$(id -u)" -x "$1" >/dev/null 2>&1; }

start_daemon() {
  case "$(backend)" in
    greenclip)
      running greenclip || { greenclip daemon >/dev/null 2>&1 & }
      ;;
    copyq)
      if ! running copyq; then
        copyq --start-server >/dev/null 2>&1 &
        # wait (max 3s) for the server so the first menu call does not race it
        for _ in $(seq 1 30); do copyq size >/dev/null 2>&1 && break; sleep 0.1; done
      fi
      ;;
    clipmenu)
      running clipmenud || { clipmenud >/dev/null 2>&1 & }
      ;;
  esac
}

case "${1:-}" in
  --daemon) start_daemon; exit 0 ;;
  --clear)
    case "$(backend)" in
      greenclip) greenclip clear ;;
      copyq)     copyq eval -- 'while (size() > 0) remove(0);' >/dev/null 2>&1 ;;
      clipmenu)  clipdel -d '.*' >/dev/null 2>&1 || true ;;
    esac
    ab_notify "Historial del portapapeles borrado"
    exit 0
    ;;
esac

ab_need_rofi
THEME='window {width: 52%;} listview {lines: 12;}'
MESG="Enter: copiar  ·  borrar historial: clipboard.sh --clear"
case "$(backend)" in
  greenclip)
    start_daemon
    rofi -modi "clip:greenclip print" -show clip -run-command '{cmd}' -mesg "$MESG" -theme-str "$THEME"
    ;;
  copyq)
    start_daemon
    # One line per item (newlines flattened, max 200 chars); rofi returns the index
    idx=$(copyq eval -- 'for (var i = 0; i < size() && i < 150; ++i) { print(str(read(i)).replace(/\s+/g, " ").slice(0, 200) + "\n"); }' 2>/dev/null \
      | ab_menu "Clip" -format i -mesg "$MESG" -theme-str "$THEME") || exit 0
    [[ "$idx" =~ ^[0-9]+$ ]] && copyq select "$idx" >/dev/null 2>&1
    ;;
  clipmenu)
    start_daemon
    CM_LAUNCHER=rofi clipmenu -p Clip -theme-str "$THEME"
    ;;
  *)
    ab_notify "Sin backend de portapapeles: corre Install.sh (greenclip) o 'sudo apt install copyq'"
    exit 1
    ;;
esac
