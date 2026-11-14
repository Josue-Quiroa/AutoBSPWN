#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — Target HUD menu (rofi). Builds on setFocus / clearFocus.
#   target-menu.sh          actions for the current focus (or "set" if there is none)
#   target-menu.sh --set    pick a recent target or type "IP [nombre]"
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
ab_need_rofi

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
HIST="$HOME/.config/bspwm/focus_history"
SSH_USERS="$AB_CACHE/ssh_users"

setfocus_bin() {
  if [ -x "$HOME/.local/bin/setFocus" ]; then echo "$HOME/.local/bin/setFocus"; else command -v setFocus; fi
}
clearfocus_bin() {
  if [ -x "$HOME/.local/bin/clearFocus" ]; then echo "$HOME/.local/bin/clearFocus"; else command -v clearFocus; fi
}

set_target() {
  local line ip name sf msg
  line=$(
    {
      [ -f "$HIST" ] && awk -F'\t' 'NF{ if ($2!="") printf "%s  %s\n", $1, $2; else print $1 }' "$HIST"
    } | ab_menu "IP [nombre]" -mesg "Escribe «10.10.11.5 box» o elige uno reciente"
  ) || exit 0
  read -r ip name <<<"$line"
  [ -n "$ip" ] || exit 0
  sf=$(setfocus_bin) || { ab_notify "setFocus no está en ~/.local/bin"; exit 1; }
  if ! msg=$("$sf" "$ip" ${name:+"$name"} 2>&1); then
    ab_notify "$msg"
    exit 1
  fi
}

ssh_target() {
  local ip=$1 dir user port=
  dir=$(ab_target_dir "$ip")
  user=$(
    { [ -f "$SSH_USERS" ] && cat "$SSH_USERS"; printf 'root\n'; } | awk '!s[$0]++' \
      | ab_menu "ssh usuario" -mesg "usuario o usuario:puerto → $ip"
  ) || return 0
  [ -n "$user" ] || return 0
  case "$user" in
    *:*) port=${user##*:}; user=${user%%:*} ;;
  esac
  if ! [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] || { [ -n "$port" ] && ! [[ "$port" =~ ^[0-9]+$ ]]; }; then
    ab_notify "Usuario/puerto inválido"
    return 1
  fi
  { printf '%s\n' "$user"; [ -f "$SSH_USERS" ] && grep -vxF "$user" "$SSH_USERS"; } | head -n 10 >"$SSH_USERS.tmp" \
    && mv -f "$SSH_USERS.tmp" "$SSH_USERS"
  # Per-target known_hosts: lab boxes get reset often and would poison ~/.ssh/known_hosts
  ab_term --title "ssh $user@$ip" -- ssh \
    -o UserKnownHostsFile="$dir/known_hosts" -o StrictHostKeyChecking=accept-new \
    ${port:+-p "$port"} "$user@$ip"
}

add_hosts() {
  local ip=$1 name=$2
  if ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    ab_notify "Nombre no válido para /etc/hosts: $name"
    return 1
  fi
  ab_term_hold bash -c 'printf "%s\t%s\n" "$1" "$2" | sudo tee -a /etc/hosts' _ "$ip" "$name"
}

ip=$(ab_focus_ip || true)
if [ "${1:-}" = --set ] || [ -z "$ip" ]; then
  set_target
  ip=$(ab_focus_ip || true)
  [ -n "$ip" ] || exit 0
  [ "${1:-}" = --set ] && exit 0
fi
name=$(ab_focus_name || true)
[ -z "$name" ] && name=$(awk -v ip="$ip" '$1==ip{print $2; exit}' /etc/hosts 2>/dev/null)
dir="$AB_TARGETS/$ip"
ports=
[ -s "$dir/ports.txt" ] && ports=$(tr -d '[:space:]' <"$dir/ports.txt")

opts=()
opts+=("󰆏  Copiar IP")
[ -n "$name" ] && opts+=("󰆏  Copiar nombre ($name)")
opts+=("󰖟  Abrir http://$ip")
opts+=("󰖟  Abrir https://$ip")
if [ -n "$name" ] && awk -v n="$name" '{for(i=2;i<=NF;i++) if($i==n){f=1}} END{exit !f}' /etc/hosts 2>/dev/null; then
  opts+=("󰖟  Abrir http://$name")
fi
# Web-ish ports found by the scans
if [ -n "$ports" ]; then
  IFS=, read -r -a plist <<<"$ports"
  for p in "${plist[@]}"; do
    case "$p" in
      80|443) ;;
      8443|9443|4443) opts+=("󰖟  Abrir https://$ip:$p") ;;
      8000|8008|8080|8081|8088|8888|3000|5000|5601|7001|8180|9000|9090|9200) opts+=("󰖟  Abrir http://$ip:$p") ;;
    esac
  done
fi
opts+=("󰣀  SSH a $ip")
opts+=("󰍉  Nmap rápido (top 1000)")
opts+=("󰍉  Nmap full TCP + -sCV")
opts+=("󰉋  Terminal en ~/targets/$ip")
opts+=("󰠮  Notas del target")
if [ -n "$name" ] && ! awk -v ip="$ip" '$1==ip{f=1} END{exit !f}' /etc/hosts 2>/dev/null; then
  opts+=("󰒓  Añadir $ip $name a /etc/hosts")
fi
opts+=("󰓾  Cambiar target")
opts+=("󰅖  Limpiar focus")

mesg="󰓾 ${name:+$name  }$ip${ports:+   ·  puertos: $ports}"
pick=$(printf '%s\n' "${opts[@]}" | ab_menu "Target" -mesg "$mesg") || exit 0

case "$pick" in
  *"Copiar IP"*)      ab_copy "$ip" && ab_notify "Copiado: $ip" ;;
  *"Copiar nombre"*)  ab_copy "$name" && ab_notify "Copiado: $name" ;;
  *"Abrir "*)         ab_browser "${pick##* }" ;;
  *"SSH a"*)          ssh_target "$ip" ;;
  *"Nmap rápido"*)    ab_target_dir "$ip" >/dev/null; ab_term --title "nmap $ip" -- bash -c '"$@"; echo; read -r -p "Enter para cerrar..." _' _ "$SCRIPTS/target-scan.sh" quick "$ip" ;;
  *"Nmap full"*)      ab_target_dir "$ip" >/dev/null; ab_term --title "nmap $ip" -- bash -c '"$@"; echo; read -r -p "Enter para cerrar..." _' _ "$SCRIPTS/target-scan.sh" full "$ip" ;;
  *"Terminal en"*)    d=$(ab_target_dir "$ip"); if ab_has kitty; then kitty --directory "$d" >/dev/null 2>&1 & else ab_term -- bash -c 'cd "$1" && exec "${SHELL:-bash}"' _ "$d"; fi ;;
  *"Notas del"*)      d=$(ab_target_dir "$ip"); ed=${EDITOR:-}
                      [ -z "$ed" ] && for e in nvim vim nano vi; do ab_has "$e" && ed=$e && break; done
                      ab_term --title "notas $ip" -- "${ed:-vi}" "$d/notes.md" ;;
  *"/etc/hosts"*)     add_hosts "$ip" "$name" ;;
  *"Cambiar target"*) set_target ;;
  *"Limpiar focus"*)  cf=$(clearfocus_bin) && "$cf" >/dev/null ;;
esac
