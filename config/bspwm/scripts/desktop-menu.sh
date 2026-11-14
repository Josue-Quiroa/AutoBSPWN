#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — right-click menu on the empty desktop (sxhkd: ~button3)
# (yoodreamer/AutoBSPWM idea: jgmenu context menu; own menu + code). Falls back to rofi.
#   desktop-menu.sh          only opens if the pointer is over the root window (wallpaper)
#   desktop-menu.sh --force  open anyway (Super+Shift+m / keyboard)
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
S="$HOME/.config/bspwm/scripts"

if [ "${1:-}" != --force ]; then
  ab_has xdotool || exit 0
  win=$(xdotool getmouselocation --shell 2>/dev/null | sed -n 's/^WINDOW=//p')
  root=$(xwininfo -root 2>/dev/null | awk '/Window id:/ {print $4}')
  [ -n "$win" ] && [ -n "$root" ] || exit 0
  [ "$win" -eq "$((root))" ] 2>/dev/null || exit 0
fi

menu() {
  cat <<CSV
Terminal,kitty,utilities-terminal
Navegador,$S/browser.sh,web-browser
Archivos,$S/files.sh,system-file-manager
Aplicaciones,rofi -show drun,applications-all
^sep()
Target HUD,$S/target-menu.sh,crosshairs
VPN / labs,$S/vpn-menu.sh,network-vpn
Tools de pentest,$S/tools-menu.sh,applications-system
Portapapeles,$S/clipboard.sh,edit-paste
Captura de pantalla,$S/screenshot.sh area,applets-screenshooter
^sep()
Wallpaper,$S/wallpaper.sh,preferences-desktop-wallpaper
Tema,$S/theme-menu.sh,preferences-desktop-theme
Atajos de teclado,$S/keys-help.sh,preferences-desktop-keyboard-shortcuts
Ventanas ocultas,$S/hide-node.sh --menu,window-restore
^sep()
Recargar bspwm,bspc wm -r,view-refresh
Bloquear,$S/lock.sh,system-lock-screen
Apagar / reiniciar…,$S/power-menu.sh,system-shutdown
CSV
}

if ab_has jgmenu; then
  pkill -u "$(id -u)" -x jgmenu 2>/dev/null
  menu | jgmenu --simple --at-pointer >/dev/null 2>&1 &
  exit 0
fi
ab_need_rofi
mapfile -t rows < <(menu | grep -v '^\^sep')
i=$(for r in "${rows[@]}"; do printf '%s\n' "${r%%,*}"; done | ab_menu "Menú" -format i -no-custom) || exit 0
[[ "$i" =~ ^[0-9]+$ ]] || exit 0
cmd=${rows[$i]#*,}; cmd=${cmd%,*}
setsid -f bash -c "$cmd" >/dev/null 2>&1
