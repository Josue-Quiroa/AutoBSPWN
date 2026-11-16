#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — Target HUD menu (rofi). Builds on setFocus / clearFocus / targetFav.
#   target-menu.sh           actions for the active target (or "set" if there is none)
#   target-menu.sh --set     pick a saved/recent target or type "IP [nombre]"
#   target-menu.sh --saved   saved targets (favorites): pick one = make it active
#   target-menu.sh --manage  remove saved targets
# Saved targets: ~/.config/bspwm/targets.tsv (ip<TAB>nombre<TAB>etiqueta), via targetFav.
# Quick commands: ~/.config/bspwm/target-commands.conf ("Etiqueta | comando {ip} {name} {dir} {ports}").
# v3.3: scope guard (~/targets/<ip>/scope.conf) before anything that touches the target,
# recon through tscan, and every action is logged in ~/targets/<ip>/timeline.tsv.
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
ab_need_rofi

HIST="$HOME/.config/bspwm/focus_history"
FAVS="$HOME/.config/bspwm/targets.tsv"
CMDS="$HOME/.config/bspwm/target-commands.conf"
TPL_DIR="$HOME/.config/bspwm/templates"
SSH_USERS="$AB_CACHE/ssh_users"

setfocus_bin() {
  if [ -x "$HOME/.local/bin/setFocus" ]; then echo "$HOME/.local/bin/setFocus"; else command -v setFocus; fi
}
clearfocus_bin() {
  if [ -x "$HOME/.local/bin/clearFocus" ]; then echo "$HOME/.local/bin/clearFocus"; else command -v clearFocus; fi
}

targetfav_bin() {
  if [ -x "$HOME/.local/bin/targetFav" ]; then echo "$HOME/.local/bin/targetFav"; else command -v targetFav; fi
}

# Saved targets first (★), then recent ones not saved; one line per IP.
#   "★ 10.10.11.42  certified.htb  · HTB AD"   /   "  10.10.11.7  box"
target_lines() {
  {
    [ -f "$FAVS" ] && awk -F'\t' '!/^[[:space:]]*#/ && NF && $1!="" {print "F\t" $1 "\t" $2 "\t" $3}' "$FAVS"
    [ -f "$HIST" ] && awk -F'\t' 'NF && $1!="" {print "H\t" $1 "\t" $2 "\t"}' "$HIST"
  } | awk -F'\t' -v star="󰓎" '!seen[$2]++ {
      line = ($1 == "F" ? star " " : "  ") $2
      if ($3 != "") line = line "  " $3
      if ($4 != "") line = line "  · " $4
      print line }'
}

# "★ ip  name  · tag" / typed "ip name" → sets $sel_ip $sel_name $sel_tag
parse_line() {
  local l=$1 rest
  l=${l#"󰓎 "}
  sel_tag=
  case "$l" in *" · "*) sel_tag=${l#*" · "}; l=${l%%" · "*} ;; esac
  read -r sel_ip sel_name rest <<<"$l"
  if [ -n "${rest:-}" ] && [ -z "$sel_tag" ]; then sel_tag=$rest; fi
  return 0
}

focus_on() {
  local sf msg
  sf=$(setfocus_bin) || { ab_notify "setFocus no está en ~/.local/bin"; return 1; }
  if ! msg=$("$sf" "$1" ${2:+"$2"} 2>&1); then
    ab_notify "$msg"
    return 1
  fi
  ab_timeline "$1" focus "target activo${2:+ ($2)}"
}

# Scope guard for HUD actions: 0 = go. Out of scope → critical notification + explicit choice.
FORCED=0
scope_ok() {
  local what=$1 rc=0 ans
  FORCED=0
  ab_scope_check "$ip" >/dev/null || rc=$?
  [ "$rc" -eq 1 ] || return 0
  ab_notify_crit "$what: $ip está FUERA DE SCOPE ($AB_SCOPE_REASON)" "Fuera de scope"
  ans=$(printf '%s\n' "󰅖  Cancelar" "󰀦  Lanzar igualmente (--force)" \
    | ab_menu "Fuera de scope" -mesg "$ip: $AB_SCOPE_REASON · ${AB_SCOPE_SRC/#$HOME/\~}") || return 1
  case "$ans" in
    *"Lanzar igualmente"*) FORCED=1; ab_timeline "$ip" scope-force "$what"; return 0 ;;
  esac
  ab_timeline "$ip" scope-block "$what"
  return 1
}

tscan_bin() {
  if [ -x "$HOME/.local/bin/tscan" ]; then echo "$HOME/.local/bin/tscan"; else command -v tscan; fi
}

run_tscan() {   # run_tscan <profile>
  local t fa=()
  t=$(tscan_bin) || { ab_notify "tscan no está en ~/.local/bin (./Install.sh --update)"; return 1; }
  scope_ok "tscan $1" || return 0
  [ "$FORCED" = 1 ] && fa=(--force)
  AB_SCOPE_FORCE_LOGGED=$FORCED ab_term --title "tscan $1 $ip" -- \
    bash -c '"$@"; echo; read -r -p "Enter para cerrar..." _' _ "$t" "${fa[@]}" "$1" "$ip"
}

set_target() {
  local line
  line=$(target_lines | ab_menu "IP [nombre]" \
    -mesg "󰓎 = guardado · escribe «10.10.11.5 box» o elige uno") || exit 0
  parse_line "$line"
  [ -n "$sel_ip" ] || exit 0
  focus_on "$sel_ip" "$sel_name" || exit 1
}

saved_targets() {
  local line tf msg add="󰐕  Guardar un target nuevo (IP [nombre] [etiqueta])" cur
  cur=$(ab_focus_ip || true)
  line=$(
    {
      [ -f "$FAVS" ] && awk -F'\t' -v cur="$cur" -v star="󰓎" '!/^[[:space:]]*#/ && NF && $1!="" {
          line = ($1 == cur ? "● " : star " ") $1
          if ($2 != "") line = line "  " $2
          if ($3 != "") line = line "  · " $3
          print line }' "$FAVS"
      printf '%s\n' "$add"
    } | ab_menu "Guardados" -mesg "Elige uno para hacerlo el target activo · o escribe «IP nombre etiqueta» para guardarlo"
  ) || return 0
  tf=$(targetfav_bin) || { ab_notify "targetFav no está en ~/.local/bin"; return 1; }
  if [ "$line" = "$add" ]; then
    line=$(printf '' | ab_menu "IP nombre etiqueta" -mesg "p. ej. 10.10.11.42 certified.htb HTB AD") || return 0
  fi
  line=${line#"● "}
  parse_line "$line"
  [ -n "$sel_ip" ] || return 0
  # Typed (not in the file yet) → save it first
  if ! "$tf" has "$sel_ip"; then
    msg=$("$tf" add "$sel_ip" "$sel_name" "$sel_tag" 2>&1) || { ab_notify "$msg"; return 1; }
  fi
  focus_on "$sel_ip" "$sel_name"
}

manage_favs() {
  local line tf msg
  [ -s "$FAVS" ] && [ -n "$(awk -F'\t' '!/^[[:space:]]*#/ && NF' "$FAVS")" ] || { ab_notify "No hay targets guardados"; return 0; }
  line=$(awk -F'\t' '!/^[[:space:]]*#/ && NF && $1!="" { l = $1; if ($2 != "") l = l "  " $2; if ($3 != "") l = l "  · " $3; print l }' "$FAVS" \
    | ab_menu "Quitar" -mesg "Elige el target guardado que quieres quitar (el historial no se toca)") || return 0
  parse_line "$line"
  [ -n "$sel_ip" ] || return 0
  tf=$(targetfav_bin) || return 1
  msg=$("$tf" rm "$sel_ip" 2>&1)
  ab_notify "$msg"
}

# ---- quick commands (~/.config/bspwm/target-commands.conf) ----
CMD_LABELS=(); CMD_LINES=()
load_commands() {
  local line label cmd
  [ -r "$CMDS" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    [[ $line == *"|"* ]] || continue
    label=${line%%|*}; cmd=${line#*|}
    label=$(printf '%s' "$label" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    cmd=$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$label" ] && [ -n "$cmd" ] || continue
    CMD_LABELS+=("$label"); CMD_LINES+=("$cmd")
  done <"$CMDS"
}

# {ip} {name} {dir} {ports} become quoted references to env vars ("${AB_IP}" …) and the values
# travel in the environment: a hostile target name can never inject code, whether the user wrote
# the placeholder bare or inside "...". Nothing from the history is ever eval'd.
run_command() {
  local label=$1 cmd=$2 d
  d=$(ab_target_dir "$ip")
  cmd=${cmd//"{ip}"/'"${AB_IP}"'}
  cmd=${cmd//"{name}"/'"${AB_NAME}"'}
  cmd=${cmd//"{dir}"/'"${AB_DIR}"'}
  cmd=${cmd//"{ports}"/'"${AB_PORTS}"'}
  AB_IP=$ip AB_NAME=$name AB_DIR=$d AB_PORTS=$ports \
    ab_term --title "$label · $ip" -- bash -c 'cd -- "$AB_DIR" 2>/dev/null
      printf "\033[1m%s\033[0m  (%s%s)\n" "$2" "$AB_IP" "${AB_NAME:+ $AB_NAME}"
      bash -c "$1"; rc=$?; echo; read -r -p "[exit $rc] Enter para cerrar..." _' _ "$cmd" "$label"
}

edit_commands() {
  local ed
  if [ ! -f "$CMDS" ]; then
    mkdir -p "$(dirname "$CMDS")"
    if [ -f "$TPL_DIR/target-commands.conf" ]; then cp "$TPL_DIR/target-commands.conf" "$CMDS"
    else printf '# Etiqueta | comando  — variables: {ip} {name} {dir} {ports}\n# Ping | ping -c4 {ip}\n' >"$CMDS"; fi
  fi
  ed=${EDITOR:-}
  [ -z "$ed" ] && for e in nvim vim nano vi; do ab_has "$e" && ed=$e && break; done
  ab_term --title "comandos rápidos" -- "${ed:-vi}" "$CMDS"
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

case "${1:-}" in
  --saved)  saved_targets; exit 0 ;;
  --manage) manage_favs; exit 0 ;;
esac

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
opts+=("󰍉  Recon rápido · tscan fast (top 1000)")
opts+=("󰍉  Recon full TCP · tscan full (-p- y -sCV)")
opts+=("󰍉  Recon UDP · tscan udp (top 100)")
opts+=("󰍉  Recon AD · tscan ad (DNS, Kerberos, LDAP, SMB, WinRM)")
opts+=("󰉋  Terminal en ~/targets/$ip")
opts+=("󰠮  Notas del target")
opts+=("󰒃  Editar scope (scope.conf)")
opts+=("󰋚  Timeline y loot del target")
if [ -n "$name" ] && ! awk -v ip="$ip" '$1==ip{f=1} END{exit !f}' /etc/hosts 2>/dev/null; then
  opts+=("󰒓  Añadir $ip $name a /etc/hosts")
fi
# Saved targets / favorites
tf=$(targetfav_bin 2>/dev/null || true)
if [ -n "$tf" ] && "$tf" has "$ip"; then
  opts+=("󰓒  Quitar de guardados ($ip)")
else
  opts+=("󰓎  Guardar en targets ($ip${name:+ $name})")
fi
opts+=("󰉹  Targets guardados")
# User quick commands (target-commands.conf)
load_commands
for i in "${!CMD_LABELS[@]}"; do opts+=("󰆍  ${CMD_LABELS[$i]}"); done
opts+=("󰏫  Editar comandos rápidos")
opts+=("󰓾  Cambiar target")
opts+=("󰅖  Limpiar focus")

mesg="󰓾 ${name:+$name  }$ip${ports:+   ·  puertos: $ports}"
scope_rc=0
ab_scope_check "$ip" >/dev/null || scope_rc=$?
case $scope_rc in
  0) mesg="$mesg   ·  scope ✓" ;;
  1) mesg="$mesg   ·  ⚠ FUERA DE SCOPE ($AB_SCOPE_REASON)" ;;
esac
pick=$(printf '%s\n' "${opts[@]}" | ab_menu "Target" -mesg "$mesg") || exit 0

# Timeline: the action label only (never command lines: they may carry passwords)
ab_timeline "$ip" hud "${pick#*  }"

# Quick commands first: their labels are free text and must not hit the built-in patterns
for i in "${!CMD_LABELS[@]}"; do
  if [ "$pick" = "󰆍  ${CMD_LABELS[$i]}" ]; then
    scope_ok "${CMD_LABELS[$i]}" || exit 0
    # forced from the HUD → the nmap/ffuf wrappers inside the command must not block it again
    AB_SCOPE_CHECKED=$FORCED run_command "${CMD_LABELS[$i]}" "${CMD_LINES[$i]}"
    exit 0
  fi
done

case "$pick" in
  *"Copiar IP"*)      ab_copy "$ip" && ab_notify "Copiado: $ip" ;;
  *"Copiar nombre"*)  ab_copy "$name" && ab_notify "Copiado: $name" ;;
  *"Abrir "*)         scope_ok "navegador" && ab_browser "${pick##* }" ;;
  *"SSH a"*)          scope_ok "ssh" && ssh_target "$ip" ;;
  *"tscan fast"*)     run_tscan fast ;;
  *"tscan full"*)     run_tscan full ;;
  *"tscan udp"*)      run_tscan udp ;;
  *"tscan ad"*)       run_tscan ad ;;
  *"Terminal en"*)    d=$(ab_target_dir "$ip"); if ab_has kitty; then kitty --directory "$d" >/dev/null 2>&1 & else ab_term -- bash -c 'cd "$1" && exec "${SHELL:-bash}"' _ "$d"; fi ;;
  *"Notas del"*)      d=$(ab_target_dir "$ip"); ed=${EDITOR:-}
                      [ -z "$ed" ] && for e in nvim vim nano vi; do ab_has "$e" && ed=$e && break; done
                      ab_term --title "notas $ip" -- "${ed:-vi}" "$d/notes.md" ;;
  *"/etc/hosts"*)     add_hosts "$ip" "$name" ;;
  *"Editar scope"*)   d=$(ab_target_dir "$ip"); ed=${EDITOR:-}
                      [ -f "$d/scope.conf" ] || printf '# in: 10.10.11.0/24\n# out: 10.10.11.1\n' >"$d/scope.conf"
                      [ -z "$ed" ] && for e in nvim vim nano vi; do ab_has "$e" && ed=$e && break; done
                      ab_term --title "scope $ip" -- "${ed:-vi}" "$d/scope.conf" ;;
  *"Timeline y loot"*) d=$(ab_target_dir "$ip")
                      ab_term --title "timeline $ip" -- bash -c 'for f in "$1/timeline.tsv" "$1/loot/index.tsv"; do echo "== ${f#"$1"/}"; if [ -s "$f" ]; then column -t -s "	" "$f" 2>/dev/null || cat "$f"; else echo "(vacío)"; fi; echo; done; read -r -p "Enter para cerrar..." _' _ "$d" ;;
  *"Guardar en targets"*)
                      # a name targetFav refuses (spaces, odd chars) → save the IP alone
                      if [ -n "$tf" ] && { msg=$("$tf" add "$ip" "$name" 2>&1) || msg=$("$tf" add "$ip" 2>&1); }; then ab_notify "$msg"
                      else ab_notify "${msg:-targetFav no está instalado}"; fi ;;
  *"Quitar de guardados"*) msg=$("$tf" rm "$ip" 2>&1); ab_notify "$msg" ;;
  *"Targets guardados"*) saved_targets ;;
  *"Editar comandos rápidos"*) edit_commands ;;
  *"Cambiar target"*) set_target ;;
  *"Limpiar focus"*)  cf=$(clearfocus_bin) && "$cf" >/dev/null ;;
esac
