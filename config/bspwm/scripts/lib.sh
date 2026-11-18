# AutoBSPWN v3.4.0 shared helpers for the rofi menus (source me; do not execute).
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

# Per-target working dir: ~/targets/<ip>/{nmap,loot,exploits,notes.md,scope.conf}
# ~/targets and every target dir are 0700 (loot, hashes and notes live there).
ab_target_dir() {
  local d="$AB_TARGETS/$1" tpl="$HOME/.config/bspwm/templates/scope.conf"
  mkdir -p "$d/nmap" "$d/loot" "$d/exploits" 2>/dev/null || true
  chmod 700 "$AB_TARGETS" "$d" "$d/loot" 2>/dev/null || true
  [ -f "$d/notes.md" ] || printf '# %s\n\n## Puertos\n\n## Notas\n' "$1" >"$d/notes.md" 2>/dev/null || true
  # scope.conf is the user's file: seed the commented template only if it is missing
  if [ ! -e "$d/scope.conf" ] && [ -f "$tpl" ]; then cp "$tpl" "$d/scope.conf" 2>/dev/null || true; fi
  printf '%s\n' "$d"
}

# ---- timeline: one line per HUD action in ~/targets/<ip>/timeline.tsv ----
#   ab_timeline <ip> <acción> [detalle]   (never pass secrets / full command lines here)
ab_timeline() {
  local ip=${1:-} act=${2:-} det=${3:-} f
  ab_is_ipv4 "$ip" || return 0
  f="$(ab_target_dir "$ip")/timeline.tsv"
  [ -s "$f" ] || printf '# hora\tacción\tdetalle\n' >"$f" 2>/dev/null || return 0
  act=${act//[$'\t\r\n']/ }; det=${det//[$'\t\r\n']/ }
  printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$act" "${det:0:200}" >>"$f" 2>/dev/null || true
}

ab_notify_crit() {
  ab_has notify-send || return 0
  notify-send -u critical -a AutoBSPWN "${2:-AutoBSPWN}" "$1" 2>/dev/null || true
}

# ---- scope guard -----------------------------------------------------------------------
# ~/targets/<ip>/scope.conf:   in: <CIDR|IP|a.b.c.x-y|host|*.dominio>   out: <...>
# Exclusions (out:) always win. No "in:" lines → everything not excluded is in scope.
# No rules at all → "no-scope" (nothing is blocked). Offline only: host names are matched
# by pattern and through /etc/hosts (AB_HOSTS_FILE), never through DNS.
AB_SCOPE_IN=(); AB_SCOPE_OUT=(); AB_SCOPE_BAD=(); AB_SCOPE_REASON=""; AB_SCOPE_SRC=""; AB_SCOPE_STATUS=""

ab_is_ipv4() {
  [[ ${1:-} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  (( 10#${BASH_REMATCH[1]} <= 255 && 10#${BASH_REMATCH[2]} <= 255 && 10#${BASH_REMATCH[3]} <= 255 && 10#${BASH_REMATCH[4]} <= 255 ))
}

ab_ip2int() {
  local a b c d
  IFS=. read -r a b c d <<<"$1"
  echo $(( (10#$a << 24) | (10#$b << 16) | (10#$c << 8) | 10#$d ))
}

# "lo hi" (integers) for an IP, a CIDR, a last-octet range (10.0.0.5-20) or 10.0.0.*
ab_net_range() {
  local s=${1:-} ip bits=32 lo hi mask
  if [[ $s =~ ^(([0-9]{1,3}\.){3})([0-9]{1,3})-([0-9]{1,3})$ ]]; then
    local first="${BASH_REMATCH[1]}${BASH_REMATCH[3]}" last="${BASH_REMATCH[1]}${BASH_REMATCH[4]}"
    ab_is_ipv4 "$first" && ab_is_ipv4 "$last" || return 1
    lo=$(ab_ip2int "$first"); hi=$(ab_ip2int "$last")
    (( lo <= hi )) || return 1
    echo "$lo $hi"; return 0
  fi
  [[ $s =~ ^(([0-9]{1,3}\.){3})\*$ ]] && s="${BASH_REMATCH[1]}0/24"
  ip=${s%/*}
  if [[ $s == */* ]]; then
    bits=${s#*/}
    [[ $bits =~ ^[0-9]{1,2}$ ]] && (( 10#$bits <= 32 )) || return 1
    bits=$((10#$bits))
  fi
  ab_is_ipv4 "$ip" || return 1
  lo=$(ab_ip2int "$ip")
  if (( bits == 0 )); then mask=0; else mask=$(( (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF )); fi
  lo=$(( lo & mask )); hi=$(( lo | (~mask & 0xFFFFFFFF) ))
  echo "$lo $hi"
}

# host matches pattern: exact name, or *.dominio = any subdomain (not the bare domain)
ab_host_match() {
  local h=${1,,} p=${2,,}
  h=${h%.}; p=${p%.}
  [ -n "$h" ] && [ -n "$p" ] || return 1
  if [[ $p == '*.'* ]]; then
    [[ $h == *."${p#\*.}" ]]
  else
    [[ $h == "$p" ]]
  fi
}

ab_is_hostname() { [[ ${1:-} =~ ^[A-Za-z0-9_*]([A-Za-z0-9_.*-]*[A-Za-z0-9_])?$ ]] && [[ $1 == *[A-Za-z_]* ]]; }

# Which scope.conf applies: $AB_SCOPE_FILE → the ACTIVE target's → ~/targets/<arg>/
ab_scope_file() {
  local q=${1:-} ip
  if [ -n "${AB_SCOPE_FILE:-}" ]; then
    [ -f "$AB_SCOPE_FILE" ] && { printf '%s\n' "$AB_SCOPE_FILE"; return 0; }
    return 1
  fi
  if ip=$(ab_focus_ip 2>/dev/null) && ab_is_ipv4 "$ip" && [ -f "$AB_TARGETS/$ip/scope.conf" ]; then
    printf '%s\n' "$AB_TARGETS/$ip/scope.conf"; return 0
  fi
  if ab_is_ipv4 "$q" && [ -f "$AB_TARGETS/$q/scope.conf" ]; then
    printf '%s\n' "$AB_TARGETS/$q/scope.conf"; return 0
  fi
  return 1
}

# Parse a scope file into AB_SCOPE_IN / AB_SCOPE_OUT (invalid entries → AB_SCOPE_BAD)
ab_scope_load() {
  local f=$1 line key e vals
  AB_SCOPE_IN=(); AB_SCOPE_OUT=(); AB_SCOPE_BAD=()
  [ -r "$f" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%#*}
    [[ $line =~ ^[[:space:]]*([A-Za-z]+)[[:space:]]*:(.*)$ ]] || { [[ $line =~ [^[:space:]] ]] && AB_SCOPE_BAD+=("$line"); continue; }
    key=${BASH_REMATCH[1],,}
    read -r -a vals <<<"${BASH_REMATCH[2]//,/ }"   # no globbing: "*.corp.local" stays literal
    for e in "${vals[@]}"; do
      if ! ab_net_range "$e" >/dev/null && ! ab_is_hostname "$e"; then AB_SCOPE_BAD+=("$e"); continue; fi
      case $key in
        in|include)  AB_SCOPE_IN+=("$e") ;;
        out|exclude) AB_SCOPE_OUT+=("$e") ;;
        *) AB_SCOPE_BAD+=("$key: $e") ;;
      esac
    done
  done <"$f"
  return 0
}

# does one rule match the query? (query = "lo hi" range + list of names)
_ab_rule_hits() {
  local rule=$1 mode=$2 qlo=$3 qhi=$4 r n
  shift 4
  if r=$(ab_net_range "$rule"); then
    local lo=${r% *} hi=${r#* }
    case $mode in
      contain) [ -n "$qlo" ] && (( qlo >= lo && qhi <= hi )) && return 0 ;;
      overlap) [ -n "$qlo" ] && (( qlo <= hi && qhi >= lo )) && return 0 ;;
    esac
    return 1
  fi
  for n in "$@"; do ab_host_match "$n" "$rule" && return 0; done
  return 1
}

# ab_scope_check <ip|host|CIDR|URL>  → prints in-scope | out-of-scope | no-scope
#   exit 0 in · 1 out · 2 no scope file/rules · 3 unparseable query. Reason in AB_SCOPE_REASON.
ab_scope_check() {
  local q=${1:-} f r qlo='' qhi='' names=() n h hosts=${AB_HOSTS_FILE:-/etc/hosts} rule
  AB_SCOPE_REASON=""; AB_SCOPE_SRC=""
  # URL / host:port → host
  q=${q#*://}; q=${q#*@}
  if ! [[ $q =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then q=${q%%[/?#]*}; fi
  [[ $q == *:* ]] && q=${q%%:*}
  q=${q%.}
  if r=$(ab_net_range "$q"); then
    qlo=${r% *}; qhi=${r#* }
    if ab_is_ipv4 "$q" && [ -r "$hosts" ]; then
      while read -r n; do names+=("$n"); done < <(awk -v ip="$q" '$1==ip {for (i=2;i<=NF;i++) if ($i !~ /^#/) print $i; else break}' "$hosts" 2>/dev/null)
    fi
  elif ab_is_hostname "$q"; then
    names=("$q")
    if [ -r "$hosts" ]; then
      h=$(awk -v n="${q,,}" '$1 !~ /^#/ {for (i=2;i<=NF;i++) if (tolower($i)==n) {print $1; exit}}' "$hosts" 2>/dev/null)
      if ab_is_ipv4 "$h"; then r=$(ab_net_range "$h"); qlo=${r% *}; qhi=${r#* }; fi
    fi
  else
    AB_SCOPE_REASON="no es una IP, red ni host: $1"
    AB_SCOPE_STATUS=invalid; echo invalid; return 3
  fi
  if ! f=$(ab_scope_file "$q"); then AB_SCOPE_REASON="sin scope.conf"; AB_SCOPE_STATUS=no-scope; echo no-scope; return 2; fi
  AB_SCOPE_SRC=$f
  ab_scope_load "$f"
  if [ ${#AB_SCOPE_IN[@]} -eq 0 ] && [ ${#AB_SCOPE_OUT[@]} -eq 0 ]; then
    AB_SCOPE_REASON="scope.conf sin reglas"; AB_SCOPE_STATUS=no-scope; echo no-scope; return 2
  fi
  for rule in "${AB_SCOPE_OUT[@]}"; do
    if _ab_rule_hits "$rule" overlap "$qlo" "$qhi" "${names[@]}"; then
      AB_SCOPE_REASON="excluido por out: $rule"; AB_SCOPE_STATUS=out-of-scope; echo out-of-scope; return 1
    fi
  done
  if [ ${#AB_SCOPE_IN[@]} -eq 0 ]; then
    AB_SCOPE_REASON="sin reglas in:, no excluido"; AB_SCOPE_STATUS=in-scope; echo in-scope; return 0
  fi
  for rule in "${AB_SCOPE_IN[@]}"; do
    if _ab_rule_hits "$rule" contain "$qlo" "$qhi" "${names[@]}"; then
      AB_SCOPE_REASON="in: $rule"; AB_SCOPE_STATUS=in-scope; echo in-scope; return 0
    fi
  done
  AB_SCOPE_REASON="no aparece en ninguna regla in:"
  AB_SCOPE_STATUS=out-of-scope; echo out-of-scope; return 1
}
# Spelled as in the docs; same thing
scope-check() { ab_scope_check "$@"; }

# ab_scope_guard <force 0|1> <qué> <target...>  → 0 = go, 1 = blocked (critical notification)
ab_scope_guard() {
  local force=$1 what=$2 t rc bad=0
  shift 2
  for t in "$@"; do
    rc=0; ab_scope_check "$t" >/dev/null || rc=$?
    [ "$rc" -eq 1 ] || continue
    if [ "$force" = 1 ]; then
      echo "[!] $t FUERA DE SCOPE ($AB_SCOPE_REASON) — forzado con --force" >&2
      # (the HUD already logged its own confirmation: AB_SCOPE_FORCE_LOGGED=1)
      [ "${AB_SCOPE_FORCE_LOGGED:-0}" = 1 ] || { ab_is_ipv4 "$t" && ab_timeline "$t" "scope-force" "$what"; }
    else
      echo "[-] $what bloqueado: $t está FUERA DE SCOPE ($AB_SCOPE_REASON). Revisa $AB_SCOPE_SRC o usa --force" >&2
      ab_notify_crit "$what bloqueado: $t está fuera de scope ($AB_SCOPE_REASON)" "Fuera de scope"
      bad=1
    fi
  done
  return "$bad"
}

# First real binary called <name> in PATH, skipping AutoBSPWN's scope wrappers
ab_real_bin() {
  local name=$1 d IFS=:
  for d in $PATH; do
    [ -n "$d" ] && [ -x "$d/$name" ] && [ ! -d "$d/$name" ] || continue
    grep -q 'AUTOBSPWN-SCOPE-WRAPPER' "$d/$name" 2>/dev/null && continue
    printf '%s\n' "$d/$name"; return 0
  done
  return 1
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

# ---- persistent state: ~/.config/autobspwn/state (key=value, one per line) -----------------
#   present=0|1   presentation / recording mode       dpi=auto|96|120|...   desktops=split|each
AB_STATE="${AUTOBSPWN_STATE:-$HOME/.config/autobspwn/state}"

ab_state_get() {   # ab_state_get <key> [default]
  local k=$1 d=${2:-} v=''
  if [ -r "$AB_STATE" ]; then
    v=$(awk -v k="$k" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$AB_STATE" 2>/dev/null)
  fi
  printf '%s\n' "${v:-$d}"
}

ab_state_set() {   # ab_state_set <key> <value>   (atomic rewrite; other keys kept)
  local k=$1 v=${2:-} tmp
  [[ $k =~ ^[a-z][a-z0-9_]*$ ]] || return 1
  v=${v//[$'\r\n']/ }
  mkdir -p "$(dirname "$AB_STATE")" 2>/dev/null || return 1
  tmp=$(mktemp "$AB_STATE.XXXXXX") || return 1
  { [ -r "$AB_STATE" ] && awk -v k="$k" 'index($0, k "=") != 1' "$AB_STATE"; printf '%s=%s\n' "$k" "$v"; } >"$tmp" 2>/dev/null
  mv -f "$tmp" "$AB_STATE"
}

# presentation mode on? (hide IPs / target / VPN in the bar, notifications paused)
ab_present() { [ "$(ab_state_get present 0)" = 1 ]; }

# text for rofi -mesg / Pango markup (target names, scope reasons…)
ab_markup_escape() {
  local s=${1:-}
  s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}
  printf '%s' "$s"
}

# text for a polybar label: neutralise %{…} format tags (a hostile name could add %{A1:cmd:})
ab_polybar_escape() {
  local s=${1:-}
  s=${s//'%{'/'%%{'}    # polybar ≥ 3.6: "%%{" prints a literal "%{"
  printf '%s' "$s"
}

# ---- HiDPI ---------------------------------------------------------------------------------
# ab_calc_dpi <width px> <width mm>  → 96 | 120 | 144 | 168 | 192
# Physical size when it is sane; VMs report 0 mm (or nonsense) → 96, or 192 from 3200 px wide.
ab_calc_dpi() {
  local px=${1:-0} mm=${2:-0} raw=0
  [[ $px =~ ^[0-9]+$ ]] || px=0
  [[ $mm =~ ^[0-9]+$ ]] || mm=0
  if (( px > 0 && mm >= 100 )); then raw=$(( px * 254 / (mm * 10) )); fi
  if (( raw < 70 || raw > 400 )); then
    if (( px >= 3200 )); then echo 192; else echo 96; fi
    return 0
  fi
  if   (( raw < 125 )); then echo 96
  elif (( raw < 150 )); then echo 120
  elif (( raw < 175 )); then echo 144
  elif (( raw < 200 )); then echo 168
  else echo 192
  fi
}

# ab_scale <px at 96 dpi> <dpi>  → px scaled (rounded)
ab_scale() { echo $(( (${1:-0} * ${2:-96} + 48) / 96 )); }

# ---- multi-monitor ---------------------------------------------------------------------------
# ab_split_desktops <monitors>  → one line per monitor with its desktop names (I…X split in
# order: 2 monitors → I–V / VI–X; 3 → I–IV / V–VII / VIII–X). More than 10 monitors → D11…
ab_split_desktops() {
  local n=${1:-1} names=(I II III IV V VI VII VIII IX X) i j k=0 per rem cnt line
  [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 )) || n=1
  per=$(( 10 / n )); rem=$(( 10 % n ))
  for (( i = 0; i < n; i++ )); do
    cnt=$per; (( i < rem )) && cnt=$((cnt + 1))
    line=''
    if (( cnt == 0 )); then line="D$((i + 1))"; fi
    for (( j = 0; j < cnt; j++ )); do line+="${line:+ }${names[$k]}"; k=$((k + 1)); done
    printf '%s\n' "$line"
  done
}
