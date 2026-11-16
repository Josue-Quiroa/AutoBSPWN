#!/usr/bin/env bash
# AutoBSPWN v3.3.1 - BSPWM desktop installer
# Target: Parrot OS Home Edition (Parrot 6 "lory" / Debian 12 MATE and Parrot 7 "echo" /
#         Debian 13 KDE). Also Parrot Security and Kali Linux.
# v3.3.1: Super+u scratchpad with up to 4 tmux terminals as tabs (~/.config/autobspwn/scratch.tmux.conf)
# v3.3.0: --update / autobspwn-update (config-only sync, keeps your edited files), scope guard
#       (scope.conf, scope-check, nmap/ffuf wrappers, red target in the bar), tscan recon
#       pipeline, loot ledger + per-target timeline, bats tests + GitHub Actions CI.
# v3.2.0: saved targets (targets.tsv, Super+Alt+i, `tgt <nombre>`, targetFav), user quick
#       commands in the Target HUD (target-commands.conf), 6 new themes (Tokyo Night, Nord,
#       Gruvbox, Dracula, Rosé Pine, Catppuccin Frappé) with matching wallpapers.
# v3.1.1: resize floating windows (Super+Alt+arrows both ways, Super+right-drag), lock =
#       plain i3lock + blurred wallpaper (ImageMagick, nothing compiled; betterlockscreen /
#       i3lock-color removed), clean single rounded polybar (no overlapping blocks), eww
#       dashboard (Super+F2, bundled pinned binary).
# v3.1: picom animations + dual_kawase blur (picom >= 12; picom 10 → fade + blur; VM → fade),
#       polybar layout refresh, desktop float/tile mode (Super+Shift+s).
# v3.0: new look (pill polybar, rounded corners with picom 10/12+, thin borders, amethyst
#       theme), 9 anime/landscape wallpapers (no generated text wallpaper any more), rofi
#       wallpaper picker, calendar, cheat sheet (Super+F1), hide/restore windows,
#       screenshots, right-click desktop menu (jgmenu) and extra bspwm chords.
# v2.2: Parrot Home/Security/Kali detection, verified package names, MATE/KDE coexistence
#       (notification router, compositor/autostart guards), optional Parrot Security tools
#       (--tools none|basic|pentest|full|custom:...), tolerant apt with lock wait + logging.
# v2.1: Target HUD, VPN/lab switcher, clipboard history, theme-sync, tools launcher.
set -Eeuo pipefail
# shellcheck disable=SC2154
trap 'rc=$?; echo -e "\033[0;31m[-]\033[0m Error inesperado (código $rc) en Install.sh línea $LINENO: $BASH_COMMAND" >&2; echo "    Log: ${LOG_FILE:-?}" >&2' ERR

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info(){ echo -e "${CYAN}[*]${NC} $*"; log "INFO $*"; }
ok(){ echo -e "${GREEN}[+]${NC} $*"; log "OK $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; log "WARN $*"; WARNINGS+=("$*"); }
err(){ echo -e "${RED}[-]${NC} $*"; log "ERR $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

: "${USER:=$(id -un)}"
export USER
VERSION="3.3.1"
NICKNAME="${NICKNAME:-}"   # v3: ignored (wallpapers no longer carry text); kept so old commands still work
SKIP_UPGRADE=0
SKIP_FONTS=0
DISABLE_BACKPORTS=0
UPDATE_ONLY=0
YES=0
TOOLS_MODE="${AUTOBSPWN_TOOLS:-}"   # none|basic|pentest|full|custom:a,b ; empty = ask
TOOLS_PKGS=()
TOOLS_SIZE=""
TOOLS_NEED_GB=0
WARNINGS=()
DISTRO=""; EDITION=""; PARROT_MAJOR=0; CODENAME=""; DESKTOPS=""
BACKUP_DIR="$HOME/.config/autobspwn-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$HOME/.cache/autobspwn-install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
log(){ printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG_FILE"; }

usage() {
  cat <<USAGE
AutoBSPWN $VERSION — instalador BSPWM para Parrot OS (Home / Security) y Kali

Uso: ./Install.sh [opciones]

Opciones:
  -h, --help             Mostrar ayuda
  -y, --yes              No preguntar nada (zsh por defecto; tools = none salvo --tools)
  -n, --nickname NAME    (obsoleta en v3, se ignora: los wallpapers ya no llevan texto)
  --tools MODO           Herramientas de pentest (también: AUTOBSPWN_TOOLS=):
                           none     no instala tools (por defecto con -y)
                           basic    recon + web + passwords + post-explotación
                           pentest  basic + explotación + sniffing
                           full     todas (parrot-tools-full / kali-linux-large)
                           custom:a,b,...  categorías sueltas (ver --list-tools)
  --list-tools           Mostrar categorías y metapaquetes de tu distro y salir
  --skip-upgrade         No hacer apt full-upgrade / parrot-upgrade
  --skip-fonts           No descargar Nerd Fonts
  --disable-backports    Comentar los repos *-backports de Parrot (antes era automático)
  --update               Sólo sincronizar configs, scripts, temas, wallpapers y ATAJOS
                         (sin apt, sin upgrade, sin fuentes, sin tools; con backup). Es lo
                         que ejecuta autobspwn-update tras el git pull. No pisa tus ediciones.
  --version              Mostrar versión

Ejemplos:
  ./Install.sh                                 # interactivo (pregunta qué tools instalar)
  ./Install.sh -y                              # sin preguntas, sin tools
  ./Install.sh -y --tools basic --skip-upgrade
  ./Install.sh --tools custom:web,password,wireless
  ./Install.sh --update                        # actualizar sólo los dotfiles (o: autobspwn-update)
USAGE
}

parse_args() {
  local list_only=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --version) echo "AutoBSPWN $VERSION"; exit 0 ;;
      -y|--yes) YES=1; shift ;;
      -n|--nickname)
        if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
          err "La opción $1 requiere un nombre"; usage; exit 1
        fi
        NICKNAME="$2"; shift 2
        warn "--nickname ya no se usa en v3 (los wallpapers no llevan texto); se ignora" ;;
      --tools)
        if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
          err "--tools requiere: none|basic|pentest|full|custom:a,b"; exit 1
        fi
        TOOLS_MODE="$2"; shift 2 ;;
      --tools=*) TOOLS_MODE="${1#--tools=}"; shift ;;
      --list-tools) list_only=1; shift ;;
      --skip-upgrade) SKIP_UPGRADE=1; shift ;;
      --skip-fonts) SKIP_FONTS=1; shift ;;
      --disable-backports) DISABLE_BACKPORTS=1; shift ;;
      --update) UPDATE_ONLY=1; shift ;;
      *) err "Opción desconocida: $1"; usage; exit 1 ;;
    esac
  done
  if [ -n "$TOOLS_MODE" ]; then
    case "$TOOLS_MODE" in
      none|basic|pentest|full|custom:?*) ;;
      *) err "--tools inválido: '$TOOLS_MODE' (none|basic|pentest|full|custom:a,b)"; exit 1 ;;
    esac
  fi
  if [ "$UPDATE_ONLY" -eq 1 ]; then
    # config-only: same as --skip-upgrade --skip-fonts --tools none, and no apt at all
    if [ -n "$TOOLS_MODE" ] && [ "$TOOLS_MODE" != none ]; then
      warn "--update no instala tools: se ignora --tools $TOOLS_MODE"
    fi
    TOOLS_MODE=none; SKIP_UPGRADE=1; SKIP_FONTS=1
  fi
  if [ "$list_only" -eq 1 ]; then
    detect_os quiet
    list_tools
    exit 0
  fi
}

need_not_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    err "No ejecutes este script como root. Úsalo con tu usuario normal (pedirá sudo)."
    exit 1
  fi
}

check_sudo() {
  info "Comprobando sudo..."
  if ! sudo -v; then
    err "Se necesita sudo. Abortando."
    exit 1
  fi
  # keep sudo warm in background (long tool installs can exceed sudo's timeout)
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done ) 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
  ok "sudo OK (log: $LOG_FILE)"
}

# ---------------------------------------------------------------- package helpers
is_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

# Has an installable candidate in the configured repos (works for real packages only)
pkg_avail() {
  local c
  c=$( { apt-cache policy "$1" 2>/dev/null || true; } | awk '/Candidate:/ {c=$2} END {print c}')
  [ -n "$c" ] && [ "$c" != "(none)" ]
}

# Print the first available package name among alternatives (distro renames)
pkg_first() {
  local p
  for p in "$@"; do
    if is_installed "$p" || pkg_avail "$p"; then echo "$p"; return 0; fi
  done
  return 1
}

APT_OPTS=(-y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# apt-get with output to terminal + log; returns apt's exit code
run_apt() {
  log "RUN apt-get $*"
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get "$@" 2>&1 | tee -a "$LOG_FILE"
  return "${PIPESTATUS[0]}"
}

# pkg_batch [--recommends|--no-recommends] pkg... : batch install, then one by one.
# Unknown names are skipped with a warning; failures never abort the installer.
pkg_batch() {
  local rec=()
  case "${1:-}" in
    --recommends) rec=(--install-recommends); shift ;;
    --no-recommends) rec=(--no-install-recommends); shift ;;
  esac
  local available=() p
  for p in "$@"; do
    [ -n "$p" ] || continue
    is_installed "$p" && continue
    if pkg_avail "$p"; then available+=("$p"); else warn "Paquete no disponible en tus repos: $p (omitido)"; fi
  done
  if [ ${#available[@]} -eq 0 ]; then
    return 0
  fi
  info "Instalando ${#available[@]} paquetes: ${available[*]}"
  if ! run_apt install "${APT_OPTS[@]}" "${rec[@]}" "${available[@]}"; then
    warn "La instalación en lote falló; reintentando uno a uno..."
    run_apt -f install "${APT_OPTS[@]}" >/dev/null 2>&1 || true
    for p in "${available[@]}"; do
      is_installed "$p" && continue
      run_apt install "${APT_OPTS[@]}" "${rec[@]}" "$p" >/dev/null 2>&1 \
        && ok "$p" || warn "No se pudo instalar $p (ver log)"
    done
  fi
  return 0
}

# ---------------------------------------------------------------- OS detection
# Parrot 6 ships os-release with ID=parrot (Parrot 5/6 images built from Debian may
# also report ID=debian with NAME="Parrot ..."), so check name, codename and packages.
detect_os() {
  local quiet=${1:-}
  if [ ! -f /etc/os-release ]; then
    err "No se pudo detectar el SO (/etc/os-release)."; exit 1
  fi
  # VERSION must stay local: os-release defines it and would clobber ours
  local ID="" ID_LIKE="" NAME="" PRETTY_NAME="" VERSION="" VERSION_ID="" VERSION_CODENAME=""
  # shellcheck disable=SC1091
  . /etc/os-release
  CODENAME="${VERSION_CODENAME:-}"
  local blob="${ID} ${NAME} ${PRETTY_NAME}"
  if [ "${ID}" = kali ]; then
    DISTRO=kali
  elif [[ "${blob,,}" == *parrot* ]] || [[ "$CODENAME" =~ ^(lory|echo)$ ]] \
       || is_installed parrot-core || grep -rqs 'deb\.parrot\.sh\|parrotsec\.org' /etc/apt/sources.list /etc/apt/sources.list.d/; then
    DISTRO=parrot
  elif [[ "${ID} ${ID_LIKE}" =~ debian|ubuntu ]]; then
    DISTRO=debian
  else
    err "Soportado: Parrot y Kali (y derivados de Debian best-effort). Detectado: ${ID:-?}"; exit 1
  fi

  if [ "$DISTRO" = parrot ]; then
    PARROT_MAJOR="${VERSION_ID%%.*}"
    [[ "$PARROT_MAJOR" =~ ^[0-9]+$ ]] || PARROT_MAJOR=0
    if [ "$PARROT_MAJOR" -eq 0 ]; then
      case "$CODENAME" in lory) PARROT_MAJOR=6 ;; echo) PARROT_MAJOR=7 ;; esac
    fi
    # Home vs Security: os-release says "Parrot Security" on both, so look at the tools
    local n
    # dpkg-query exits 1 when no parrot-tools-* exist (Parrot Home) -> must not trip set -e/pipefail
    n=$( { dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'parrot-tools-*' 2>/dev/null || true; } | awk '$1 ~ /^ii/ {c++} END {print c+0}')
    if is_installed parrot-tools-full || [ "$n" -ge 3 ]; then EDITION=security; else EDITION=home; fi
  elif [ "$DISTRO" = kali ]; then
    if is_installed kali-linux-default || is_installed kali-linux-large || is_installed kali-linux-everything; then
      EDITION=tools
    else
      EDITION=minimal
    fi
  else
    EDITION=generic
  fi

  DESKTOPS=""
  command -v mate-session >/dev/null 2>&1 && DESKTOPS+="MATE "
  { command -v startplasma-x11 >/dev/null 2>&1 || command -v plasmashell >/dev/null 2>&1; } && DESKTOPS+="KDE "
  command -v xfce4-session >/dev/null 2>&1 && DESKTOPS+="XFCE "
  command -v gnome-session >/dev/null 2>&1 && DESKTOPS+="GNOME "

  [ -n "$quiet" ] && return 0
  case "$DISTRO" in
    parrot) ok "Distro: Parrot OS ${PARROT_MAJOR:-?} (${CODENAME:-?}) — edición ${EDITION^^} (${PRETTY_NAME:-})" ;;
    kali)   ok "Distro: Kali (${PRETTY_NAME:-}) — metapaquetes de tools: $([ "$EDITION" = tools ] && echo sí || echo no)" ;;
    *)      warn "SO no es Parrot/Kali (${ID:-?}). Instalación best-effort." ;;
  esac
  [ -n "$DESKTOPS" ] && info "Escritorios existentes: ${DESKTOPS% } (se conservan; bspwm se añade como sesión aparte)"
  if [ "$DISTRO" = parrot ] && [ "$PARROT_MAJOR" -ne 0 ] && [ "$PARROT_MAJOR" -lt 6 ]; then
    warn "Parrot $PARROT_MAJOR es antiguo; probado en 6.x y 7.x"
  fi
  return 0
}

# ---------------------------------------------------------------- Security tools
# Categories → metapackages, verified in the official indexes:
#   Parrot: https://deb.parrot.sh/parrot/dists/{lory,echo}/main/binary-amd64/Packages
#   Kali:   https://kali.download/kali/dists/kali-rolling/main/binary-amd64/Packages
# parrot-tools-* list their tools as Recommends → must be installed WITH recommends.
PARROT_CATS="infogathering web password postexploit pwn sniff vuln wireless forensics reversing maintain cloud reporting automotive ai"
KALI_CATS="information-gathering web passwords post-exploitation exploitation sniffing-spoofing vulnerability wireless 802-11 bluetooth forensics reverse-engineering crypto-stego database fuzzing reporting social-engineering voip windows-resources"

# Examples taken from each metapackage's Depends/Recommends in the Parrot 7 index
cat_desc() {
  [ "$DISTRO" = kali ] && { echo "kali-tools-$1"; return 0; }
  case "$1" in
    infogathering) echo "recon: nmap, masscan, theharvester, enum4linux, autorecon…" ;;
    web)           echo "web: burpsuite, caido, zaproxy, gobuster, ffuf, nikto, wpscan…" ;;
    password)      echo "passwords: hashcat, john, hydra, medusa, cewl, wordlists…" ;;
    postexploit)   echo "post-explotación: mimikatz, peass, powersploit, linux-exploit-suggester…" ;;
    pwn)           echo "explotación: metasploit, bloodhound, netexec, evil-winrm, beef-xss…" ;;
    sniff)         echo "sniffing: wireshark, responder, bettercap, ettercap…" ;;
    vuln)          echo "vulnerabilidades/fuzzing: gvm (OpenVAS), afl, VoIP/Cisco…" ;;
    wireless)      echo "wireless/bluetooth: aircrack-ng, airgeddon, wifite, reaver…" ;;
    forensics)     echo "forense: autopsy, sleuthkit, binwalk, foremost…" ;;
    reversing)     echo "reversing: ghidra, rizin/cutter, gdb, edb-debugger…" ;;
    maintain)      echo "acceso/túneles: chisel, iodine, dns2tcp, nishang…" ;;
    cloud)         echo "cloud: awscli, azure-cli, cloud-enum…" ;;
    reporting)     echo "reporting: eyewitness, logseq" ;;
    automotive)    echo "automotive: can-utils, scantool…" ;;
    ai)            echo "IA (sólo Parrot 7)" ;;
    *) echo "$1" ;;
  esac
}

cat_pkg() {
  if [ "$DISTRO" = kali ]; then echo "kali-tools-$1"; else echo "parrot-tools-$1"; fi
}

list_tools() {
  echo "Metapaquetes de tools para: $DISTRO ${PARROT_MAJOR:-}"
  if [ "$DISTRO" = kali ]; then
    echo "  basic   → kali-tools-top10"
    echo "  pentest → kali-linux-default"
    echo "  full    → kali-linux-large"
    local c; for c in $KALI_CATS; do printf '  custom:%-22s kali-tools-%s\n' "$c" "$c"; done
  else
    echo "  basic   → parrot-tools-infogathering parrot-tools-web parrot-tools-password parrot-tools-postexploit"
    echo "  pentest → basic + parrot-tools-pwn parrot-tools-sniff impacket-scripts"
    echo "  full    → parrot-tools-full"
    local c; for c in $PARROT_CATS; do printf '  custom:%-15s parrot-tools-%-15s %s\n' "$c" "$c" "$(cat_desc "$c")"; done
  fi
}

# Estimated size on top of a Parrot Home install (GiB installed / GiB download), computed
# by resolving Depends+Recommends of each set against the official Parrot Packages index
# (Nov 2026). Real numbers vary with mirror state and what you already have.
tools_size() {
  local mode=$1
  TOOLS_SIZE=""; TOOLS_NEED_GB=0
  [ "$DISTRO" = parrot ] || return 0
  local p6 p7
  case "$mode" in
    basic)   p6="5.2 GB instalado / 1.6 GB descarga"; p7="8.7 GB instalado / 2.5 GB descarga" ;;
    pentest) p6="7.1 GB instalado / 2.1 GB descarga"; p7="10.9 GB instalado / 3.2 GB descarga" ;;
    full)    p6="10.3 GB instalado / 2.9 GB descarga"; p7="15.2 GB instalado / 4.7 GB descarga" ;;
    *) return 0 ;;
  esac
  if [ "$PARROT_MAJOR" -ge 7 ] || [ "$PARROT_MAJOR" -eq 0 ]; then TOOLS_SIZE="~$p7"; else TOOLS_SIZE="~$p6"; fi
  TOOLS_NEED_GB=$(( $(printf '%s' "${TOOLS_SIZE#\~}" | awk '{printf "%d", $1 + 0.999}') + 2 ))
}

resolve_tools() {
  local mode=$1 c
  TOOLS_PKGS=()
  case "$mode" in
    none) return 0 ;;
    basic)
      if [ "$DISTRO" = kali ]; then TOOLS_PKGS=(kali-tools-top10)
      else TOOLS_PKGS=(parrot-tools-infogathering parrot-tools-web parrot-tools-password parrot-tools-postexploit); fi ;;
    pentest)
      if [ "$DISTRO" = kali ]; then TOOLS_PKGS=(kali-linux-default)
      else TOOLS_PKGS=(parrot-tools-infogathering parrot-tools-web parrot-tools-password parrot-tools-postexploit
                       parrot-tools-pwn parrot-tools-sniff impacket-scripts); fi ;;
    full)
      if [ "$DISTRO" = kali ]; then TOOLS_PKGS=(kali-linux-large); else TOOLS_PKGS=(parrot-tools-full); fi ;;
    custom:*)
      local IFS=', '
      for c in ${mode#custom:}; do
        [ -n "$c" ] && TOOLS_PKGS+=("$(cat_pkg "$c")")
      done ;;
  esac
}

choose_tools() {
  if [ "$DISTRO" = debian ]; then
    [ -n "$TOOLS_MODE" ] && [ "$TOOLS_MODE" != none ] && warn "--tools sólo aplica a Parrot/Kali; se ignora"
    TOOLS_MODE=none; return 0
  fi
  local have_tools=0
  { [ "$EDITION" = security ] || [ "$EDITION" = tools ]; } && have_tools=1

  if [ -z "$TOOLS_MODE" ]; then
    if [ "$YES" -eq 1 ]; then
      TOOLS_MODE=none
      info "Tools: none (-y sin --tools). Para instalarlas: ./Install.sh --tools basic|pentest|full"
    elif [ ! -t 0 ]; then
      TOOLS_MODE=none
      warn "Sin terminal interactiva: no se instalan tools (usa --tools)"
    else
      echo
      echo -e "${BOLD}Herramientas de pentest de la edición Security${NC}"
      if [ "$have_tools" -eq 1 ]; then
        echo -e "  ${GREEN}Tu sistema ya tiene las tools (Parrot Security / Kali con metapaquetes).${NC} Puedes omitir este paso."
      else
        echo "  Parrot Home no trae las tools de pentest; puedes añadirlas ahora (también después con --tools)."
      fi
      local s_basic s_pentest s_full kb kp kf
      if [ "$DISTRO" = kali ]; then
        kb=" (kali-tools-top10)"; kp=" (kali-linux-default)"; kf=" (kali-linux-large)"
        s_basic=""; s_pentest=""; s_full=""
      else
        kb=""; kp=""; kf=" (parrot-tools-full)"
        tools_size basic;   s_basic=${TOOLS_SIZE:+  [$TOOLS_SIZE]}
        tools_size pentest; s_pentest=${TOOLS_SIZE:+  [$TOOLS_SIZE]}
        tools_size full;    s_full=${TOOLS_SIZE:+  [$TOOLS_SIZE]}
      fi
      echo "   1) No instalar tools  (por defecto)"
      echo "   2) Básicas$kb: recon, web, passwords y post-explotación$s_basic"
      echo "   3) Pentest$kp: básicas + explotación (Metasploit, NetExec…) + sniffing (Wireshark, Responder…)$s_pentest"
      echo "   4) Todas$kf$s_full"
      echo "   5) Elegir categorías"
      [ "$DISTRO" = parrot ] && echo "   Tamaños: estimación sobre Parrot Home según el índice oficial de paquetes; pueden variar."
      local ans=""
      read -r -p "Opción [1-5] (Enter = 1): " ans || true
      case "${ans:-1}" in
        2) TOOLS_MODE=basic ;;
        3) TOOLS_MODE=pentest ;;
        4) TOOLS_MODE=full ;;
        5)
          local cats=$PARROT_CATS i=1 c pick=() sel
          [ "$DISTRO" = kali ] && cats=$KALI_CATS
          for c in $cats; do printf '   %2d) %-22s %s\n' "$i" "$c" "$(cat_desc "$c")"; i=$((i + 1)); done
          read -r -p "Números separados por espacio (ej: 1 2 3): " sel || true
          local -a arr; read -r -a arr <<<"$cats"
          for i in $sel; do
            [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le ${#arr[@]} ] && pick+=("${arr[$((i - 1))]}")
          done
          if [ ${#pick[@]} -gt 0 ]; then TOOLS_MODE="custom:$(IFS=,; echo "${pick[*]}")"; else TOOLS_MODE=none; fi ;;
        *) TOOLS_MODE=none ;;
      esac
    fi
  fi

  resolve_tools "$TOOLS_MODE"
  [ ${#TOOLS_PKGS[@]} -eq 0 ] && { ok "Tools: no se instalarán"; return 0; }

  if [ "$have_tools" -eq 1 ] && [ "$TOOLS_MODE" = full ]; then
    info "Ya tienes tools instaladas: apt sólo añadirá lo que falte."
  fi
  tools_size "$TOOLS_MODE"
  ok "Tools: $TOOLS_MODE → ${TOOLS_PKGS[*]}${TOOLS_SIZE:+ ($TOOLS_SIZE)}"

  # Free space check on / (only when we have a reliable estimate)
  if [ "$TOOLS_NEED_GB" -gt 0 ]; then
    local free_gb
    free_gb=$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')
    if [ -n "$free_gb" ] && [ "$free_gb" -lt "$TOOLS_NEED_GB" ]; then
      warn "Espacio libre en /: ${free_gb} GB; se recomiendan ≥ ${TOOLS_NEED_GB} GB para '$TOOLS_MODE'"
      if [ "$YES" -eq 0 ] && [ -t 0 ]; then
        local go=""
        read -r -p "¿Instalar tools de todos modos? [y/N] " go || true
        [[ "$go" =~ ^[YySs]$ ]] || { TOOLS_MODE=none; TOOLS_PKGS=(); ok "Tools omitidas"; }
      fi
    fi
  fi
}

install_tools() {
  [ ${#TOOLS_PKGS[@]} -gt 0 ] || return 0
  info "Instalando tools ($TOOLS_MODE): ${TOOLS_PKGS[*]} — puede tardar bastante"
  local wanted=() p
  for p in "${TOOLS_PKGS[@]}"; do
    if pkg_avail "$p" || is_installed "$p"; then wanted+=("$p"); else warn "Metapaquete no existe en tus repos: $p (omitido)"; fi
  done
  [ ${#wanted[@]} -gt 0 ] || return 0
  # --install-recommends: the metapackages pull their tools through Recommends
  if run_apt install "${APT_OPTS[@]}" --install-recommends "${wanted[@]}"; then
    ok "Tools instaladas: ${wanted[*]}"
    return 0
  fi
  warn "Falló la instalación conjunta de tools; reintentando por metapaquete..."
  run_apt -f install "${APT_OPTS[@]}" >/dev/null 2>&1 || true
  for p in "${wanted[@]}"; do
    if run_apt install "${APT_OPTS[@]}" --install-recommends "$p"; then
      ok "$p"
    else
      # last resort: the metapackage alone (its hard Depends) so the rest can be retried later
      run_apt install "${APT_OPTS[@]}" --no-install-recommends "$p" >/dev/null 2>&1 \
        && warn "$p instalado sin recommends (faltan tools): reintenta 'sudo apt install --install-recommends $p'" \
        || warn "No se pudo instalar $p (ver log)"
    fi
  done
  run_apt -f install "${APT_OPTS[@]}" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- system
backup_existing() {
  info "Respaldando configs previas en $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  local d f
  for d in bspwm sxhkd polybar picom kitty rofi dunst jgmenu eww betterlockscreen; do
    [ -d "$HOME/.config/$d" ] && cp -a "$HOME/.config/$d" "$BACKUP_DIR/" || true
  done
  for f in .zshrc .p10k.zsh .config/greenclip.toml .fehbg .config/gtk-3.0/settings.ini \
           .local/share/dbus-1/services/org.freedesktop.Notifications.service .config/autostart/picom.desktop \
           .config/autobspwn/manifest.tsv .config/autobspwn/scratch.tmux.conf; do
    if [ -f "$HOME/$f" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$f")"
      cp -a "$HOME/$f" "$BACKUP_DIR/$f"
    fi
  done
  for f in $AB_BIN_SCRIPTS nmap ffuf; do
    if [ -f "$HOME/.local/bin/$f" ]; then
      mkdir -p "$BACKUP_DIR/local-bin"
      cp -a "$HOME/.local/bin/$f" "$BACKUP_DIR/local-bin/" || true
    fi
  done
  ok "Backup listo"
}

# Opt-in only (--disable-backports): Parrot docs keep backports enabled by default.
disable_parrot_backports() {
  [ "$DISTRO" = parrot ] && [ "$DISABLE_BACKPORTS" -eq 1 ] || return 0
  local f
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    [ -f "$f" ] || continue
    if grep -qiE '^[[:space:]]*deb.*backports' "$f" 2>/dev/null; then
      warn "Comentando backports en $f (copia: $f.autobspwn.bak)"
      sudo cp -a "$f" "$f.autobspwn.bak"
      sudo sed -i -E 's/^[[:space:]]*deb(.*backports.*)/# &/I' "$f" || true
    fi
  done
  for f in /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] && grep -qi 'backports' "$f" && warn "$f (formato deb822) tiene backports: edítalo a mano si quieres quitarlos"
  done
  return 0
}

apt_update() {
  local i
  for i in 1 2; do
    run_apt update -o DPkg::Lock::Timeout=600 >/dev/null && return 0
    warn "apt update falló (intento $i); reintentando en 10 s..."
    sleep 10
  done
  warn "apt update sigue fallando: se usará la lista de paquetes en caché (revisa tus repos/red)"
  return 0
}

system_update() {
  info "Actualizando índices de paquetes..."
  apt_update
  if [ "$SKIP_UPGRADE" -eq 1 ]; then
    warn "Saltando upgrade (--skip-upgrade)"
    return 0
  fi
  info "Actualizando sistema (full-upgrade)..."
  if [ "$DISTRO" = parrot ] && command -v parrot-upgrade >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive parrot-upgrade 2>&1 | tee -a "$LOG_FILE" \
      || run_apt full-upgrade "${APT_OPTS[@]}" || warn "El upgrade falló; continúo"
  else
    run_apt full-upgrade "${APT_OPTS[@]}" || warn "El upgrade falló; continúo"
  fi
  ok "Sistema actualizado"
}

install_packages() {
  info "Instalando paquetes del entorno..."
  # Core rice (names verified in Parrot 6 lory, Parrot 7 echo and kali-rolling)
  pkg_batch \
    bspwm sxhkd polybar picom rofi feh kitty dunst \
    suckless-tools xclip xsel xdotool jq imagemagick flameshot maim \
    yad jgmenu x11-utils ncal \
    fonts-hack fonts-font-awesome fontconfig \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    fzf bat lsd git curl wget unzip ca-certificates \
    scrot bc libnotify-bin pulseaudio-utils pavucontrol \
    htop btop tmux papirus-icon-theme x11-xserver-utils xdg-utils procps

  # Pentest helpers used by the VPN switcher and Target HUD: always, also on Parrot Home
  pkg_batch --no-recommends openvpn wireguard-tools nmap network-manager-openvpn util-linux iproute2

  # Renamed / optional packages: first available name wins
  local extra=() p
  if ! command -v nm-applet >/dev/null 2>&1; then
    p=$(pkg_first network-manager-applet network-manager-gnome) && extra+=("$p")
  fi
  p=$(pkg_first fastfetch neofetch) && extra+=("$p")
  # GUI editor for OpenVPN profiles inside nm-applet / nm-connection-editor
  p=$(pkg_first network-manager-openvpn-gnome) && extra+=("$p")
  # A polkit agent only if the system has none (MATE/KDE already ship theirs)
  local agent found=0
  for agent in /usr/libexec/polkit-mate-authentication-agent-1 /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 \
               /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 /usr/libexec/polkit-kde-authentication-agent-1 \
               /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 /usr/libexec/polkit-gnome-authentication-agent-1 \
               /usr/bin/lxqt-policykit-agent /usr/bin/lxpolkit; do
    [ -x "$agent" ] && { found=1; break; }
  done
  [ "$found" -eq 0 ] && p=$(pkg_first mate-polkit) && extra+=("$p")
  # A browser only if there is none at all
  if ! command -v firefox >/dev/null 2>&1 && ! command -v firefox-esr >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
    p=$(pkg_first firefox-esr firefox) && extra+=("$p")
  fi
  # gsimplecal: calendar fallback if yad is missing; brightnessctl for laptops
  for p in gsimplecal brightnessctl fonts-noto-color-emoji; do pkg_avail "$p" && extra+=("$p"); done
  [ ${#extra[@]} -gt 0 ] && pkg_batch --no-recommends "${extra[@]}"
  ok "Paquetes base listos"
}

# ---------------------------------------------------------------- lock screen (i3lock)
# 3.1.1: plain i3lock from the distro repos (Parrot 6/7, Kali) + a pre-rendered blurred
# wallpaper made with ImageMagick (lock.sh --update). Nothing is compiled any more:
# 3.1.0's betterlockscreen + i3lock-color failed to build on Parrot, pixelated the screen
# and its fallback chain could start a second locker after unlocking.
BLS_OLD_SHA256="e625a1466395b8593ae00c901258ff9cd32695ec93601f2659409f665dca9d3b"   # 3.1.0 pinned script

install_lockscreen() {
  info "Pantalla de bloqueo: i3lock + wallpaper desenfocado..."
  # On Kali 3.1.0 installed betterlockscreen + i3lock-color (Conflicts: i3lock): apt swaps them.
  if is_installed betterlockscreen || is_installed i3lock-color; then
    info "Sustituyendo betterlockscreen / i3lock-color (v3.1.0) por i3lock"
  fi
  pkg_batch i3lock
  # Pinned betterlockscreen script dropped by 3.1.0 in ~/.local/bin: remove it only if it is ours
  local f="$HOME/.local/bin/betterlockscreen"
  if [ -f "$f" ] && [ "$(sha256sum "$f" 2>/dev/null | awk '{print $1}')" = "$BLS_OLD_SHA256" ]; then
    rm -f "$f" && info "Quitado ~/.local/bin/betterlockscreen (v3.1.0)"
  fi
  [ -x /usr/local/bin/i3lock-color ] && log "INFO /usr/local/bin/i3lock-color (3.1.0) ya no se usa; puedes borrarlo con sudo rm"
  if command -v i3lock >/dev/null 2>&1; then
    ok "i3lock listo (Super+Shift+x)"
  else
    warn "i3lock no se pudo instalar: el bloqueo probará xsecurelock o avisará (sudo apt install i3lock)"
  fi
  return 0
}

# Pre-render the blurred lock image (works without X: 1920x1080, rebuilt on the first lock
# if the real screen differs). Runs after apply_theme so it uses the theme colors.
prepare_lockscreen() {
  local s="$HOME/.config/bspwm/scripts/lock.sh"
  [ -x "$s" ] || return 0
  if ! command -v convert >/dev/null 2>&1 && ! command -v magick >/dev/null 2>&1; then
    warn "ImageMagick no está: el bloqueo será un fondo de color liso"
    return 0
  fi
  info "Generando imagen de bloqueo (wallpaper desenfocado)..."
  if timeout 120 "$s" --update >>"$LOG_FILE" 2>&1 && [ -s "${XDG_CACHE_HOME:-$HOME/.cache}/autobspwn/lock.png" ]; then
    ok "Imagen de bloqueo lista (~/.cache/autobspwn/lock.png)"
  else
    warn "No se pudo generar la imagen de bloqueo; se intentará al bloquear (ver log)"
  fi
  return 0
}

# ---------------------------------------------------------------- eww dashboard
# eww is in no Debian/Kali/Parrot repo and upstream publishes no binaries. The repo ships
# bin/eww-x86_64: eww v0.6.0 (X11 only) built on Debian 12 (glibc 2.36 → runs on Parrot 6/7
# and Kali), checked against bin/eww-x86_64.sha256. Fallback: build from the pinned source
# with cargo if a new enough rustc (>= 1.76) is installed. Otherwise skip (Super+F2 says so).
EWW_TAG="v0.6.0"
EWW_SRC_SHA256="cef361946946c566b79f8ddc6208d1a3f16b4ff9961439a3f86935e1cfa174a1"

eww_ok() { [ -x "$HOME/.local/bin/eww" ] && "$HOME/.local/bin/eww" --version >/dev/null 2>&1; }

eww_runtime_deps() {
  local p extra=()
  p=$(pkg_first libgtk-3-0t64 libgtk-3-0) && extra+=("$p")
  p=$(pkg_first libdbusmenu-gtk3-4) && extra+=("$p")
  [ ${#extra[@]} -gt 0 ] && pkg_batch --no-recommends "${extra[@]}"
  return 0
}

build_eww_cargo() {
  command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1 || return 1
  local rv maj min
  rv=$(rustc --version 2>/dev/null | awk '{print $2}')
  maj=${rv%%.*}; min=${rv#*.}; min=${min%%.*}
  if ! [[ $maj =~ ^[0-9]+$ && $min =~ ^[0-9]+$ ]] || [ "$maj" -lt 1 ] || { [ "$maj" -eq 1 ] && [ "$min" -lt 76 ]; }; then
    warn "eww: rustc $rv es demasiado viejo para compilar eww (necesita >= 1.76)"
    return 1
  fi
  info "Compilando eww $EWW_TAG con cargo (puede tardar 5-15 min)..."
  pkg_batch --no-recommends pkg-config libgtk-3-dev libdbusmenu-gtk3-dev
  local tmp tgz src
  tmp=$(mktemp -d /tmp/autobspwn-eww.XXXXXX) || return 1
  tgz="$tmp/eww.tar.gz"
  if ! curl -fL --connect-timeout 20 --retry 2 -o "$tgz" \
       "https://github.com/elkowar/eww/archive/refs/tags/$EWW_TAG.tar.gz" >>"$LOG_FILE" 2>&1 \
     || [ "$(sha256sum "$tgz" | awk '{print $1}')" != "$EWW_SRC_SHA256" ]; then
    warn "eww: no se pudo descargar/verificar el código fuente"; rm -rf "$tmp"; return 1
  fi
  tar xzf "$tgz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  src="$tmp/eww-${EWW_TAG#v}"
  if ( cd "$src" && cargo build --release --locked --no-default-features --features x11 ) >>"$LOG_FILE" 2>&1; then
    install -m 0755 "$src/target/release/eww" "$HOME/.local/bin/eww" || true
  fi
  rm -rf "$tmp"
  eww_ok
}

install_eww() {
  info "Dashboard eww (Super+F2)..."
  mkdir -p "$HOME/.local/bin"
  if [ "$(uname -m)" != x86_64 ]; then
    warn "eww: el binario incluido es x86_64; en $(uname -m) se intentará compilar"
  fi
  eww_runtime_deps
  local bin="$SCRIPT_DIR/bin/eww-x86_64" sum="$SCRIPT_DIR/bin/eww-x86_64.sha256" want
  if [ "$(uname -m)" = x86_64 ] && [ -f "$bin" ] && [ -f "$sum" ]; then
    want=$(awk '{print $1; exit}' "$sum")
    if [ "$(sha256sum "$bin" | awk '{print $1}')" = "$want" ]; then
      install -m 0755 "$bin" "$HOME/.local/bin/eww" || true
      if eww_ok; then
        ok "eww instalado en ~/.local/bin ($("$HOME/.local/bin/eww" --version 2>/dev/null | head -n1), build $EWW_TAG)"
        return 0
      fi
      log "WARN eww incluido no arranca: $("$HOME/.local/bin/eww" --version 2>&1 | head -n3 | tr '\n' ' ')"
      rm -f "$HOME/.local/bin/eww"
    else
      warn "eww: checksum del binario incluido no coincide; no se instala"
    fi
  fi
  if build_eww_cargo; then
    ok "eww compilado e instalado en ~/.local/bin"
    return 0
  fi
  warn "eww no disponible: el dashboard (Super+F2) mostrará un aviso. Polybar sigue siendo la barra principal"
  return 0
}

# ---------------------------------------------------------------- picom profile
# bspwmrc picks the profile at every login (picom can be upgraded later, e.g. Parrot 6 → 7);
# here we check it once, tell the user and leave ~/.config/picom/active.conf pointing to it.
setup_picom_profile() {
  local sel="$HOME/.config/bspwm/scripts/picom-profile.sh" first
  command -v picom >/dev/null 2>&1 || { warn "picom no instalado: sin bordes redondeados/animaciones"; return 0; }
  [ -x "$sel" ] || return 0
  first=$("$sel" 2>/dev/null | head -n1 || true)
  if [ -n "$first" ] && [ -f "$first" ]; then
    ln -sfn "$first" "$HOME/.config/picom/active.conf" 2>/dev/null || true
    ok "picom: $("$sel" --explain 2>/dev/null || basename "$first")"
  else
    warn "picom: no se encontró el perfil ($first)"
  fi
  return 0
}

# ---------------------------------------------------------------- fonts / clipboard / shell
# Download a Nerd Font zip, trying several URLs. Returns 0 on success.
download_nerd_zip() {
  local dest=$1
  shift
  local url
  rm -f "$dest"
  for url in "$@"; do
    info "Descargando $url"
    if curl -fL --connect-timeout 20 --retry 2 -o "$dest" "$url"; then
      if [ -s "$dest" ] && unzip -t -q "$dest" >/dev/null 2>&1; then
        return 0
      fi
    fi
    rm -f "$dest"
  done
  return 1
}

font_already() {
  local pattern=$1
  find "$HOME/.local/share/fonts" /usr/share/fonts /usr/local/share/fonts \
    -iname "$pattern" -print -quit 2>/dev/null | grep -q .
}

install_nerd_font() {
  if [ "$SKIP_FONTS" -eq 1 ]; then
    warn "Saltando Nerd Fonts (--skip-fonts)"
    return 0
  fi

  mkdir -p "$HOME/.local/share/fonts"

  local hack_ok=0 jb_ok=0
  font_already '*Hack*Nerd*' && hack_ok=1 && ok "Hack Nerd Font ya presente"
  font_already '*JetBrainsMono*Nerd*' && jb_ok=1 && ok "JetBrainsMono Nerd Font ya presente"

  # Prefer 'latest', then pinned known-good tags (v3.3.0 still exists if latest changes)
  if [ "$hack_ok" -eq 0 ]; then
    info "Instalando Hack Nerd Font..."
    local zip="/tmp/HackNerdFont.zip"
    local fontdir="$HOME/.local/share/fonts/HackNerdFont"
    mkdir -p "$fontdir"
    if download_nerd_zip "$zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Hack.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.zip"
    then
      unzip -o -q "$zip" -d "$fontdir" || warn "unzip de Hack falló"
      rm -f "$zip"
      hack_ok=1
      ok "Hack Nerd Font instalada"
    else
      warn "No se pudo descargar Hack Nerd Font (usarás fonts-hack)"
    fi
  fi

  if [ "$jb_ok" -eq 0 ]; then
    info "Instalando JetBrainsMono Nerd Font..."
    local jb="/tmp/JBMonoNerdFont.zip"
    local jbdir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    mkdir -p "$jbdir"
    if download_nerd_zip "$jb" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip"
    then
      unzip -o -q "$jb" -d "$jbdir" || warn "unzip de JetBrainsMono falló"
      rm -f "$jb"
      jb_ok=1
      ok "JetBrainsMono Nerd Font instalada"
    else
      warn "No se pudo descargar JetBrainsMono Nerd Font (polybar/kitty usarán Hack si está)"
    fi
  fi

  if [ "$hack_ok" -eq 1 ] || [ "$jb_ok" -eq 1 ]; then
    fc-cache -fv >/dev/null 2>&1 || true
  fi
}

# Clipboard history: greenclip (single static x86_64 binary, native rofi mode).
# Not packaged in Kali/Parrot → download from GitHub releases with version fallback.
# If that fails (offline / ARM) → copyq from apt (packaged in Parrot 6/7 and Kali).
# Only one backend daemon is ever started (clipboard.sh --daemon picks it).
install_clipboard() {
  if command -v greenclip >/dev/null 2>&1 || [ -x "$HOME/.local/bin/greenclip" ]; then
    ok "greenclip ya instalado"
    return 0
  fi
  mkdir -p "$HOME/.local/bin"
  local arch tmp url
  arch=$(uname -m)
  if [ "$arch" = x86_64 ]; then
    tmp=$(mktemp /tmp/greenclip.XXXXXX)
    for url in \
      "https://github.com/erebe/greenclip/releases/latest/download/greenclip" \
      "https://github.com/erebe/greenclip/releases/download/v4.2/greenclip" \
      "https://github.com/erebe/greenclip/releases/download/4.1/greenclip"
    do
      info "Descargando greenclip: $url"
      if curl -fL --connect-timeout 20 --retry 2 -o "$tmp" "$url" 2>/dev/null \
         && [ "$(head -c 4 "$tmp" | od -An -c | tr -d ' ')" = "177ELF" ]; then
        # Not executed here on purpose: any greenclip command writes a default
        # ~/.config/greenclip.toml, which would shadow the one AutoBSPWN deploys.
        if [ "$(stat -c %s "$tmp" 2>/dev/null || echo 0)" -gt 1000000 ]; then
          install -m 0755 "$tmp" "$HOME/.local/bin/greenclip"
          rm -f "$tmp"
          ok "greenclip instalado en ~/.local/bin"
          return 0
        fi
      fi
    done
    rm -f "$tmp"
    warn "No se pudo descargar greenclip; usando copyq (apt) como respaldo"
  else
    warn "greenclip sólo publica binario x86_64 ($arch): usando copyq"
  fi
  pkg_batch --no-recommends copyq
  if command -v copyq >/dev/null 2>&1; then
    ok "copyq instalado (respaldo de greenclip)"
  else
    warn "Sin historial de portapapeles (ni greenclip ni copyq). Super+c avisará."
  fi
}

install_p10k() {
  if [ -d "$HOME/powerlevel10k" ]; then
    ok "Powerlevel10k ya existe"
    return 0
  fi
  info "Clonando Powerlevel10k..."
  if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"; then
    ok "Powerlevel10k instalado"
  else
    warn "No se pudo clonar Powerlevel10k (red). zsh funcionará igual, sin el tema p10k."
  fi
}

ensure_path_file() {
  # Append PATH (and Java WM fix) to a profile file if missing
  local f=$1
  touch "$f"
  if ! grep -q '\.local/bin' "$f" 2>/dev/null; then
    printf '\n# AutoBSPWN\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$f"
  fi
  if ! grep -q '_JAVA_AWT_WM_NONREPARENTING' "$f" 2>/dev/null; then
    printf 'export _JAVA_AWT_WM_NONREPARENTING=1\n' >>"$f"
  fi
}

# ---------------------------------------------------------------- deploy (manifest)
# ~/.config/autobspwn/manifest.tsv remembers the checksum of every file AutoBSPWN installed.
# On a reinstall / --update a file is replaced only if you did not edit it since; an edited
# file is kept and the new version is written next to it as <file>.autobspwn-new.
# Files theme-sync regenerates are always replaced (the theme is re-applied right after), and
# the theme-sync block inside dunstrc is ignored when comparing.
AB_BIN_SCRIPTS="setFocus clearFocus targetFav polybar-theme extractHosts theme-sync autobspwn-notifyd scope-check tscan loot autobspwn-update"
AB_MANIFEST="$HOME/.config/autobspwn/manifest.tsv"
AB_THEME_OWNED=" .config/polybar/colors.ini .config/kitty/theme.conf .config/rofi/colors.rasi .config/eww/colors.scss "
declare -gA AB_MAN_OLD=() AB_MAN_NEW=()
KEPT_FILES=()

file_sum() {
  awk '/^# >>> autobspwn-theme/ {s=1; next} /^# <<< autobspwn-theme/ {s=0; next} !s' "$1" 2>/dev/null \
    | sha256sum | awk '{print $1}'
}

manifest_load() {
  AB_MAN_OLD=(); AB_MAN_NEW=(); KEPT_FILES=()
  [ -f "$AB_MANIFEST" ] || return 0
  local rel sum
  while IFS=$'\t' read -r rel sum; do
    [ -n "$rel" ] && [ -n "$sum" ] && AB_MAN_OLD[$rel]=$sum
  done <"$AB_MANIFEST"
  return 0
}

manifest_save() {
  local k
  mkdir -p "$(dirname "$AB_MANIFEST")"
  for k in "${!AB_MAN_NEW[@]}"; do printf '%s\t%s\n' "$k" "${AB_MAN_NEW[$k]}"; done | sort >"$AB_MANIFEST.tmp" \
    && mv -f "$AB_MANIFEST.tmp" "$AB_MANIFEST"
  return 0
}

# deploy_file <src> <dst> [mode]
deploy_file() {
  local src=$1 dst=$2 mode=${3:-} rel new cur old
  rel=${dst#"$HOME"/}
  new=$(file_sum "$src")
  if [ -f "$dst" ]; then
    cur=$(file_sum "$dst")
    if [ "$cur" = "$new" ]; then
      [ -n "$mode" ] && chmod "$mode" "$dst" 2>/dev/null
      rm -f "$dst.autobspwn-new"
      AB_MAN_NEW[$rel]=$new
      return 0
    fi
    old=${AB_MAN_OLD[$rel]:-}
    # edited by you since the last install (and not a theme-sync file) → keep it
    if [ -n "$old" ] && [ "$cur" != "$old" ] && [[ $AB_THEME_OWNED != *" $rel "* ]]; then
      cp -f "$src" "$dst.autobspwn-new" 2>/dev/null || true
      KEPT_FILES+=("$rel")
      AB_MAN_NEW[$rel]=$old
      return 0
    fi
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -n "$mode" ]; then
    install -m "$mode" "$src" "$dst"
  else
    cp -a "$src" "$dst"
  fi
  rm -f "$dst.autobspwn-new"
  AB_MAN_NEW[$rel]=$new
  return 0
}

# deploy_tree <src dir> <dst dir>
deploy_tree() {
  local src=$1 dst=$2 f
  while IFS= read -r -d '' f; do
    deploy_file "$f" "$dst/${f#"$src"/}"
  done < <(find "$src" -type f -print0)
}

# nmap / ffuf scope guards in ~/.local/bin (opt out: touch ~/.config/autobspwn/no-scope-wrappers)
install_scope_wrappers() {
  local w dst src="$SCRIPT_DIR/scripts/autobspwn-scope-wrapper"
  [ -f "$src" ] || return 0
  for w in nmap ffuf; do
    dst="$HOME/.local/bin/$w"
    if [ -f "$HOME/.config/autobspwn/no-scope-wrappers" ]; then
      if grep -q 'AUTOBSPWN-SCOPE-WRAPPER' "$dst" 2>/dev/null; then rm -f "$dst"; fi
      continue
    fi
    if [ -e "$dst" ] && ! grep -q 'AUTOBSPWN-SCOPE-WRAPPER' "$dst" 2>/dev/null; then
      warn "$HOME/.local/bin/$w ya existe y no es de AutoBSPWN: sin guardia de scope para $w"
      continue
    fi
    deploy_file "$src" "$dst" 0755
  done
  return 0
}

deploy_configs() {
  info "Desplegando configs..."
  mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/bspwm/walls" "$HOME/Pictures"
  manifest_load

  local d
  for d in bspwm sxhkd polybar picom kitty rofi dunst eww; do
    [ -d "$SCRIPT_DIR/config/$d" ] || continue
    mkdir -p "$HOME/.config/$d"
    deploy_tree "$SCRIPT_DIR/config/$d" "$HOME/.config/$d"
  done

  deploy_file "$SCRIPT_DIR/home/.zshrc" "$HOME/.zshrc"
  deploy_file "$SCRIPT_DIR/home/.p10k.zsh" "$HOME/.p10k.zsh"

  local s
  for s in $AB_BIN_SCRIPTS; do
    [ -f "$SCRIPT_DIR/scripts/$s" ] && deploy_file "$SCRIPT_DIR/scripts/$s" "$HOME/.local/bin/$s" 0755
  done
  install_scope_wrappers
  # autobspwn-update finds the clone through this file
  mkdir -p "$HOME/.config/autobspwn"
  # Super+u scratchpad: its own tmux config (tabs, Alt keys, max 4); your edits are kept
  [ -f "$SCRIPT_DIR/config/autobspwn/scratch.tmux.conf" ] && \
    deploy_file "$SCRIPT_DIR/config/autobspwn/scratch.tmux.conf" "$HOME/.config/autobspwn/scratch.tmux.conf"
  printf '%s\n' "$SCRIPT_DIR" >"$HOME/.config/autobspwn/repo"

  # First install only (keeps the user's own settings)
  if [ ! -f "$HOME/.config/greenclip.toml" ] && [ -f "$SCRIPT_DIR/config/greenclip/greenclip.toml" ]; then
    cp -a "$SCRIPT_DIR/config/greenclip/greenclip.toml" "$HOME/.config/greenclip.toml"
  fi
  if [ ! -f "$HOME/.config/gtk-3.0/settings.ini" ] && [ -f "$SCRIPT_DIR/config/gtk-3.0/settings.ini" ]; then
    mkdir -p "$HOME/.config/gtk-3.0"
    cp -a "$SCRIPT_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
  fi
  # Target HUD (v3.2): saved targets + quick commands are the user's files — seed only if missing
  local tpl
  for tpl in targets.tsv target-commands.conf; do
    if [ ! -e "$HOME/.config/bspwm/$tpl" ] && [ -f "$SCRIPT_DIR/config/bspwm/templates/$tpl" ]; then
      cp "$SCRIPT_DIR/config/bspwm/templates/$tpl" "$HOME/.config/bspwm/$tpl" || true
    fi
  done
  # Pentest workspace: ~/vpn (*.ovpn / WireGuard *.conf) and ~/targets/<ip>/ (Target HUD)
  mkdir -p "$HOME/vpn" "$HOME/targets"
  chmod 700 "$HOME/vpn" 2>/dev/null || true
  # Cheat sheet (also generated live by Super+F1 from sxhkdrc)
  if [ -f "$SCRIPT_DIR/ATAJOS.md" ]; then
    cp -f "$SCRIPT_DIR/ATAJOS.md" "$HOME/.config/bspwm/ATAJOS.md"
    if [ ! -e "$HOME/ATAJOS.md" ] || grep -q 'autobspwn-atajos' "$HOME/ATAJOS.md" 2>/dev/null; then
      cp -f "$SCRIPT_DIR/ATAJOS.md" "$HOME/ATAJOS.md"
    fi
  fi

  find "$HOME/.config/bspwm" "$HOME/.config/polybar" "$HOME/.config/eww" -type f \( -name '*.sh' -o -name 'bspwmrc' \) -exec chmod +x {} + 2>/dev/null || true
  # libcolors.sh / lib.sh are sourced, keep them non-executable (still readable)
  [ -f "$HOME/.config/polybar/scripts/libcolors.sh" ] && chmod 644 "$HOME/.config/polybar/scripts/libcolors.sh"
  [ -f "$HOME/.config/bspwm/scripts/lib.sh" ] && chmod 644 "$HOME/.config/bspwm/scripts/lib.sh"

  if [ -d "$SCRIPT_DIR/wallpapers" ]; then
    find "$SCRIPT_DIR/wallpapers" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -exec cp -a {} "$HOME/.config/bspwm/walls/" \;
  fi

  # Display managers may source .profile, .xprofile, or .zprofile — cover all three
  ensure_path_file "$HOME/.profile"
  ensure_path_file "$HOME/.xprofile"
  ensure_path_file "$HOME/.zprofile"

  manifest_save
  if [ ${#KEPT_FILES[@]} -gt 0 ]; then
    local k
    for k in "${KEPT_FILES[@]}"; do
      warn "Conservado tu ~/$k (lo editaste); la versión nueva está en ~/$k.autobspwn-new"
    done
  fi
  ok "Configs desplegadas"
}

# Keep MATE / KDE / XFCE sessions intact next to bspwm:
#  * dunst and mate-notification-daemon (or xfce4-notifyd, plasma) all claim
#    org.freedesktop.Notifications via D-Bus activation and the winner is arbitrary.
#    A per-user service file (searched before /usr/share) points to autobspwn-notifyd,
#    which starts dunst only under bspwm and the desktop's own daemon elsewhere.
#  * the picom package autostarts picom in EVERY XDG session (no OnlyShowIn), where it
#    fights marco/kwin/xfwm4 compositing. bspwmrc launches picom itself, so hide it.
desktop_coexistence() {
  local svc_dir="$HOME/.local/share/dbus-1/services"
  local svc="$svc_dir/org.freedesktop.Notifications.service"
  mkdir -p "$svc_dir"
  if [ -f "$svc" ] && ! grep -q 'autobspwn' "$svc"; then
    warn "Ya tienes $svc propio; no lo toco (dunst/MATE podrían pelear por las notificaciones)"
  else
    cat >"$svc" <<SVC
# autobspwn: route notifications to dunst only inside bspwm (see ~/.local/bin/autobspwn-notifyd)
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=$HOME/.local/bin/autobspwn-notifyd
SVC
    ok "Router de notificaciones: dunst en bspwm, el daemon nativo en MATE/KDE/XFCE"
  fi

  if [ -f /etc/xdg/autostart/picom.desktop ]; then
    local ov="$HOME/.config/autostart/picom.desktop"
    if [ ! -f "$ov" ]; then
      mkdir -p "$HOME/.config/autostart"
      cat >"$ov" <<'DESK'
[Desktop Entry]
# autobspwn: picom is started by bspwmrc; do not autostart it in MATE/KDE/XFCE
Type=Application
Name=picom
Exec=picom
Hidden=true
DESK
      ok "picom desactivado en el autostart de otros escritorios (bspwm lo lanza solo)"
    fi
  fi
}

# v2 → v3: the old installer generated text wallpapers (walls/default.png and
# walls/<theme>.png). theme-sync prefers walls/<theme>.png, so move them out of the way,
# drop a .fehbg that points to them, and switch once to the new amethyst look.
migrate_v2() {
  local w="$HOME/.config/bspwm/walls" marker="$HOME/.config/bspwm/.autobspwn-v3" f moved=0
  [ -f "$marker" ] && return 0
  for f in default mocha macchiato hacker; do
    if [ -f "$w/$f.png" ]; then
      mkdir -p "$BACKUP_DIR/walls-v2"
      mv -f "$w/$f.png" "$BACKUP_DIR/walls-v2/" && moved=1
    fi
  done
  if [ -f "$HOME/.config/bspwm/nickname" ]; then
    mkdir -p "$BACKUP_DIR"
    mv -f "$HOME/.config/bspwm/nickname" "$BACKUP_DIR/" || true
  fi
  if [ -f "$HOME/.fehbg" ] && grep -Eq "/walls/(default|mocha|macchiato|hacker)\.png" "$HOME/.fehbg"; then
    mv -f "$HOME/.fehbg" "$BACKUP_DIR/fehbg.v2" 2>/dev/null || rm -f "$HOME/.fehbg"
  fi
  if [ -f "$HOME/.config/polybar/.current-theme" ]; then
    printf 'amethyst\n' >"$HOME/.config/polybar/.current-theme"
    info "v3: tema cambiado a amethyst (vuelve al tuyo con: theme-sync mocha)"
  fi
  [ "$moved" -eq 1 ] && ok "Wallpapers con texto de v2 movidos a $BACKUP_DIR/walls-v2"
  date -Iseconds >"$marker" 2>/dev/null || true
}

# Re-apply the saved theme (default amethyst) to the freshly copied configs:
# kitty theme.conf, rofi colors.rasi, dunst block, polybar colors.ini, wallpaper
apply_theme() {
  local ts="$HOME/.local/bin/theme-sync"
  [ -x "$ts" ] || { warn "theme-sync no instalado"; return 0; }
  local cur
  cur=$("$ts" --current 2>/dev/null || echo amethyst)
  if "$ts" "$cur" --no-reload >/dev/null 2>&1; then
    ok "Tema aplicado: $cur (Super+Shift+t para ciclar)"
  else
    warn "No se pudo aplicar el tema $cur; usando amethyst"
    "$ts" amethyst --no-reload >/dev/null 2>&1 || true
  fi
}

# The bspwm package already ships /usr/share/xsessions/bspwm.desktop (LightDM on
# Parrot MATE, SDDM on Parrot KDE / Kali); only create it if it is missing.
ensure_xsessions() {
  local desk="/usr/share/xsessions/bspwm.desktop"
  if [ ! -f "$desk" ]; then
    info "Creando sesión bspwm en el login manager..."
    sudo tee "$desk" >/dev/null <<'DESK'
[Desktop Entry]
Name=bspwm
Comment=Binary space partitioning window manager
Exec=bspwm
TryExec=bspwm
Type=Application
DesktopNames=bspwm;
DESK
    ok "xsessions/bspwm.desktop creado"
  else
    ok "Sesión bspwm disponible en el login (X11)"
  fi
  if [ -f /etc/sddm.conf ] || [ -d /etc/sddm.conf.d ] || [ "$(cat /etc/X11/default-display-manager 2>/dev/null)" = /usr/bin/sddm ]; then
    info "SDDM: elige la sesión 'bspwm' (X11) en el selector de sesión de la esquina"
  fi
}

maybe_chsh() {
  local zsh_path cur
  zsh_path="$(command -v zsh || true)"
  [ -n "$zsh_path" ] || return 0
  cur=$(getent passwd "$USER" | cut -d: -f7)
  if [ "$cur" = "$zsh_path" ] || [ "$cur" = /bin/zsh ] || [ "$cur" = /usr/bin/zsh ]; then
    ok "zsh ya es tu shell"
    return 0
  fi
  local ans=""
  if [ "$YES" -eq 1 ]; then
    ans=y
  elif [ -t 0 ]; then
    warn "Tu shell actual es ${cur:-desconocida}."
    read -r -p "¿Cambiar shell a zsh ahora? [y/N] " ans || true
  fi
  if [[ "${ans:-}" =~ ^[YySs]$ ]]; then
    # sudo (already cached) avoids a second PAM password prompt from chsh
    sudo chsh -s "$zsh_path" "$USER" && ok "Shell cambiada a zsh (aplica al re-login)" || warn "chsh falló"
  fi
}

verify_install() {
  info "Verificando binarios clave..."
  local missing=0 b
  for b in bspwm sxhkd polybar picom rofi feh kitty dunst; do
    if command -v "$b" >/dev/null 2>&1; then ok "$b"; else warn "Falta: $b"; missing=1; fi
  done
  if command -v greenclip >/dev/null 2>&1 || [ -x "$HOME/.local/bin/greenclip" ]; then
    ok "greenclip (portapapeles)"
  elif command -v copyq >/dev/null 2>&1; then
    ok "copyq (portapapeles, respaldo)"
  else
    warn "Sin historial de portapapeles"
  fi
  if command -v i3lock >/dev/null 2>&1; then
    if [ -s "${XDG_CACHE_HOME:-$HOME/.cache}/autobspwn/lock.png" ]; then
      ok "i3lock + imagen desenfocada (bloqueo)"
    else
      ok "i3lock (bloqueo; la imagen se genera al primer bloqueo)"
    fi
  else
    warn "Sin bloqueador de pantalla (i3lock)"
  fi
  if eww_ok; then
    ok "eww (dashboard Super+F2)"
  else
    warn "Opcional ausente: eww (dashboard Super+F2)"
  fi
  for b in yad jgmenu maim xprop openvpn wg-quick nmcli nmap nm-applet xclip jq; do
    command -v "$b" >/dev/null 2>&1 && ok "$b" || warn "Opcional ausente: $b"
  done
  local p
  for p in "${TOOLS_PKGS[@]}"; do
    is_installed "$p" && ok "tools: $p" || warn "tools: $p no quedó instalado"
  done
  [ "$missing" -eq 0 ] && ok "Verificación OK" || warn "Hay binarios faltantes; revisa el log"
}

# ---------------------------------------------------------------- --update (config-only)
# eww: only (re)install the bundled binary when there is no working eww (never replace a
# cargo build); no apt for its libraries here.
update_eww_binary() {
  eww_ok && return 0
  local bin="$SCRIPT_DIR/bin/eww-x86_64" sum="$SCRIPT_DIR/bin/eww-x86_64.sha256" want
  [ "$(uname -m)" = x86_64 ] && [ -f "$bin" ] && [ -f "$sum" ] || return 0
  want=$(awk '{print $1; exit}' "$sum")
  [ "$(sha256sum "$bin" | awk '{print $1}')" = "$want" ] || { warn "eww: checksum del binario incluido no coincide"; return 0; }
  install -m 0755 "$bin" "$HOME/.local/bin/eww" || true
  if eww_ok; then ok "eww instalado (dashboard Super+F2)"; else rm -f "$HOME/.local/bin/eww"; warn "eww no arranca aquí (falta GTK); usa ./Install.sh completo"; fi
  return 0
}

# Reload whatever is running in this X session (nothing to do from a TTY / SSH)
reload_session() {
  local uid
  uid=$(id -u)
  if [ "${AUTOBSPWN_NO_RELOAD:-0}" = 1 ] || [ -z "${DISPLAY:-}" ]; then
    info "Sin sesión gráfica: los cambios se aplican al entrar en bspwm"
    return 0
  fi
  if pgrep -u "$uid" -x bspwm >/dev/null 2>&1 && command -v bspc >/dev/null 2>&1; then
    # bspwmrc runs again: borders, rules, picom profile and polybar (launch.sh)
    if bspc wm -r >/dev/null 2>&1; then ok "bspwm recargado (relanza polybar)"; else warn "bspc wm -r falló"; fi
  elif pgrep -u "$uid" -x polybar >/dev/null 2>&1 && [ -x "$HOME/.config/polybar/launch.sh" ]; then
    setsid -f "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 </dev/null || true
    ok "polybar relanzada"
  fi
  if pgrep -u "$uid" -x sxhkd >/dev/null 2>&1; then
    pkill -USR1 -u "$uid" -x sxhkd 2>/dev/null && ok "sxhkd recargado (atajos nuevos activos)" || true
  fi
  return 0
}

update_main() {
  echo -e "${CYAN}AutoBSPWN $VERSION${NC} — actualización de configs (sin apt, sin upgrade, sin fuentes, sin tools)"
  need_not_root
  backup_existing
  deploy_configs
  update_eww_binary
  setup_picom_profile
  desktop_coexistence
  migrate_v2
  apply_theme
  prepare_lockscreen
  reload_session
  echo
  ok "AutoBSPWN $VERSION sincronizado"
  info "Backup: $BACKUP_DIR"
  info "Log:    $LOG_FILE"
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Avisos (${#WARNINGS[@]}):${NC}"
    printf '  - %s\n' "${WARNINGS[@]}"
  fi
  return 0
}

main() {
  parse_args "$@"
  if [ "$UPDATE_ONLY" -eq 1 ]; then
    update_main
    return 0
  fi
  echo -e "${CYAN}"
  cat <<'BANNER'
    _         _        ____  ____  ______        ___   __
   / \  _   _| |_ ___ | __ )|  _ \/ ___\ \      / / \ | |
  / _ \| | | | __/ _ \|  _ \| |_) \___ \\ \ /\ / / _ \| |
 / ___ \ |_| | || (_) | |_) |  __/ ___) |\ V  V / ___ \ |
/_/   \_\__,_|\__\___/|____/|_|   |____/  \_/\_/_/   \_\
BANNER
  echo -e "${NC}v$VERSION"
  need_not_root
  detect_os
  check_sudo
  # every question first, so the long part can run unattended
  choose_tools
  backup_existing
  disable_parrot_backports
  system_update
  install_packages
  install_nerd_font
  install_clipboard
  install_p10k
  install_lockscreen
  install_eww
  deploy_configs
  setup_picom_profile
  desktop_coexistence
  migrate_v2
  apply_theme
  prepare_lockscreen
  ensure_xsessions
  maybe_chsh
  install_tools
  verify_install

  echo
  ok "Instalación AutoBSPWN $VERSION terminada"
  info "Backup: $BACKUP_DIR"
  info "Log:    $LOG_FILE"
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Avisos (${#WARNINGS[@]}):${NC}"
    printf '  - %s\n' "${WARNINGS[@]}"
  fi
  echo
  echo -e "${YELLOW}Siguiente paso:${NC}"
  echo "  1. Cierra sesión (o reinicia). Tu escritorio ${DESKTOPS:-anterior }sigue disponible."
  echo "  2. En el login (LightDM/SDDM), elige la sesión: bspwm"
  echo "  3. Super+F1 (o Super+/) muestra TODOS los atajos · también en ~/ATAJOS.md"
  echo "  4. Super+Enter (kitty) · Super+d (rofi) · Super+w (wallpapers) · Super+e (archivos)"
  echo "  5. Target HUD: Super+i (menú) · setFocus 10.10.10.10 box · tscan fast · loot · scope-check"
  echo "  6. VPN: copia tus .ovpn a ~/vpn → Super+v (Super+Shift+v reconecta)"
  echo "  7. Portapapeles: Super+c · Tools: Super+p · Capturas: Print / Super+a"
  echo "  8. Temas: Super+Shift+t (ciclar) · Super+Alt+t (menú) · theme-sync mocha"
  echo "  9. Calendario: clic en el reloj (o Super+Alt+c) · Scratchpad: Super+u"
  echo " 10. Ventanas: Super+s flotante↔mosaico · Super+Shift+s escritorio flotante · Super+Alt+flechas redimensionar"
  echo " 11. Dashboard: Super+F2 (Esc cierra) · Bloquear: Super+Shift+x · Actualizar: autobspwn-update"
  [ "$TOOLS_MODE" = none ] && echo " 12. Tools de Parrot Security cuando quieras: ./Install.sh -y --skip-upgrade --tools basic"
  echo
}

main "$@"
