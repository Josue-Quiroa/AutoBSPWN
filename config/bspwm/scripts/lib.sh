# AutoBSPWN v3.2.0 shared helpers for the rofi menus (source me; do not execute).
# shellcheck shell=bash disable=SC2034

AB_TARGETS="${AUTOBSPWN_TARGETS:-$HOME/targets}"
AB_VPN_DIR="${AUTOBSPWN_VPN_DIR:-$HOME/vpn}"
AB_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/autobspwn"
AB_FOCUS_IP="$HOME/.config/bspwm/focus_ip"
AB_FOCUS_NAME="$HOME/.config/bspwm/focus_name"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$AB_CACHE" 2>/dev/null || true

ab_has() { command -v "$1" >/dev/null 2>&1; }

ab_notify() {
  ab_has notify-send || return 0
  notify-send -a AutoBSPWN "${2:-AutoBSPWN}" "$1" 2>/dev/null || true
}

# Copy to the CLIPBOARD selection (xclip, then xsel)
ab_copy() {
  if ab_has xclip; then
    printf '%s' "$1" | xclip -selection clipboard 2>/dev/null && return 0
  fi
  if ab_has xsel; then
    printf '%s' "$1" | xsel -ib 2>/dev/null && return 0
  fi
  ab_notify "Instala xclip o xsel para copiar"
  return 1
}

# ab_menu <prompt> [extra rofi args...]   (reads options from stdin)
ab_menu() {
  local p=$1
  shift
  rofi -dmenu -i -p "$p" "$@"
}

ab_need_rofi() {
  ab_has rofi && return 0
  ab_notify "rofi no está instalado"
  exit 1
}

# ab_term [kitty-args...] -- cmd args...   floating terminal running a command
ab_term() {
  local kargs=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do kargs+=("$1"); shift; done
  [ "${1:-}" = -- ] && shift
  if ab_has kitty; then
    kitty --class floating "${kargs[@]}" "$@" >/dev/null 2>&1 &
  elif ab_has x-terminal-emulator; then
    x-terminal-emulator -e "$@" >/dev/null 2>&1 &
  else
    ab_notify "No hay terminal (kitty)"
    return 1
  fi
}

# Same as ab_term but waits for Enter before closing (for scans / sudo output)
ab_term_hold() {
  ab_term -- bash -c '"$@"; rc=$?; echo; read -r -p "[exit $rc] Enter para cerrar..." _' _ "$@"
}

ab_browser() {
  local url=$1 b
  for b in firefox firefox-esr chromium chromium-browser google-chrome brave-browser; do
    if ab_has "$b"; then
      "$b" "$url" >/dev/null 2>&1 &
      return 0
    fi
  done
  if ab_has xdg-open; then
    xdg-open "$url" >/dev/null 2>&1 &
    return 0
  fi
  ab_notify "No hay navegador"
  return 1
}

# File manager that does not hijack the desktop: caja/nemo/nautilus draw a full-screen
# desktop window (icons over the wallpaper) unless told not to.
ab_files() {
  local dir=${1:-$HOME}
  if ab_has caja; then caja --no-desktop "$dir" >/dev/null 2>&1 &
  elif ab_has thunar; then thunar "$dir" >/dev/null 2>&1 &
  elif ab_has dolphin; then dolphin "$dir" >/dev/null 2>&1 &
  elif ab_has pcmanfm; then pcmanfm "$dir" >/dev/null 2>&1 &
  elif ab_has nemo; then nemo --no-desktop "$dir" >/dev/null 2>&1 &
  elif ab_has nautilus; then nautilus --new-window "$dir" >/dev/null 2>&1 &
  else
    local fm
    for fm in ranger nnn lf; do
      if ab_has "$fm"; then ab_term -- "$fm" "$dir"; return 0; fi
    done
    ab_term -- bash -c 'cd "$1" && exec "${SHELL:-bash}"' _ "$dir"
  fi
}

ab_focus_ip() {
  [ -f "$AB_FOCUS_IP" ] || return 1
  local ip
  ip=$(tr -d '[:space:]' <"$AB_FOCUS_IP")
  [ -n "$ip" ] || return 1
  printf '%s\n' "$ip"
}

ab_focus_name() {
  [ -f "$AB_FOCUS_NAME" ] || return 1
  local n
  n=$(head -n1 "$AB_FOCUS_NAME" | tr -d '\r')
  [ -n "$n" ] || return 1
  printf '%s\n' "$n"
}

# Per-target working dir: ~/targets/<ip>/{nmap,loot,exploits,notes.md}
ab_target_dir() {
  local d="$AB_TARGETS/$1"
  mkdir -p "$d/nmap" "$d/loot" "$d/exploits" 2>/dev/null || true
  [ -f "$d/notes.md" ] || printf '# %s\n\n## Puertos\n\n## Notas\n' "$1" >"$d/notes.md" 2>/dev/null || true
  printf '%s\n' "$d"
}

# Run a command as root from a GUI context.
# sudo -n (cached / NOPASSWD) → pkexec (polkit agent) → terminal asking for the password
ab_root() {
  if sudo -n true 2>/dev/null; then
    sudo -n "$@"
    return $?
  fi
  local bin
  bin=$(command -v "$1" 2>/dev/null || true)
  if [ -n "$bin" ] && ab_has pkexec \
     && pgrep -u "$(id -u)" -f 'polkit-[a-z]+-authentication-agent|lxpolkit|lxqt-policykit-agent' >/dev/null 2>&1; then
    shift
    pkexec "$bin" "$@"
    return $?
  fi
  ab_term_hold sudo "$@"
}
