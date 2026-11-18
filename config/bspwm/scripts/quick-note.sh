#!/usr/bin/env bash
# AutoBSPWN v3.4.2 — quick notes (Super+Alt+n · or `note` in a terminal)
#   quick-note.sh                 popup (rofi, yad as fallback): one line · Alt+d (rofi) or the
#                                 "Ver / borrar" button (yad) = list the notes and delete some
#   quick-note.sh <texto…>        add a note without popup (use -- before text starting with -)
#   quick-note.sh --list          numbered notes            --path   file in use
#   quick-note.sh --rm N [M…]     delete notes N, M… (also 2,5 or 3-6); asks in a terminal
#   quick-note.sh --rm-all        delete every note (asks to type BORRAR; --yes skips it)
#   quick-note.sh --manage        popup to view / delete (multi-select, confirmation)
# Active target → ~/targets/<ip>/notes.md (+ a line in its timeline.tsv: only that a note was
# added / deleted and how many, never the text). No target → ~/notes/inbox.md.
# A note is a line "- [YYYY-mm-dd HH:MM] texto"; deleting only removes those lines (headers and
# anything you wrote by hand stay). The text is only written with printf: nothing is executed.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

INBOX="${AUTOBSPWN_NOTES:-$HOME/notes}/inbox.md"
NOTE_RE='^- [[][0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9][]] '   # no backslashes or {n}: safe for awk -v and old mawk

ip=$(ab_focus_ip 2>/dev/null || true)
ab_is_ipv4 "$ip" || ip=''
name=$(ab_focus_name 2>/dev/null || true)

if [ -n "$ip" ]; then F="$AB_TARGETS/$ip/notes.md"; else F=$INBOX; fi
dest=${F/#"$HOME"/\~}

where() { if [ -n "$ip" ]; then echo "${name:+$name · }$ip → notes.md"; else echo "sin target → ~/notes/inbox.md"; fi; }

# notes: the note lines of $F (text only, in file order)
notes() { [ -f "$F" ] && grep -E "$NOTE_RE" "$F" 2>/dev/null; return 0; }
count() { notes | wc -l; }

list() {
  local n
  n=$(count)
  if [ "$n" -eq 0 ]; then echo "(sin notas en $dest)"; return 0; fi
  echo "# $dest"
  notes | awk '{ printf "%3d  %s\n", NR, substr($0, 3) }'
}

# expand "2,5 3-6 1" → sorted unique numbers in 1..count, or fail
parse_nums() {
  local max=$1; shift
  local grp tok a b i out=()
  for grp in "${@//,/ }"; do
    for tok in $grp; do
      if [[ $tok =~ ^[0-9]+$ ]]; then a=$tok; b=$tok
      elif [[ $tok =~ ^([0-9]+)-([0-9]+)$ ]]; then a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
      else echo "[!] número no válido: $tok" >&2; return 1; fi
      (( a >= 1 && b <= max && a <= b )) || { echo "[!] fuera de rango (1-$max): $tok" >&2; return 1; }
      for ((i = a; i <= b; i++)); do out+=("$i"); done
    done
  done
  [ ${#out[@]} -gt 0 ] || { echo "[!] ¿qué nota? (note --list)" >&2; return 1; }
  printf '%s\n' "${out[@]}" | sort -nu
}

# delete_notes <n>…  (numbers from list); rewrite atomically, keep 600
delete_notes() {
  local tmp n
  [ $# -gt 0 ] || return 0
  local lines
  # file line numbers of the chosen notes (grep -E finds the notes; awk only counts lines, so the
  # result never depends on the awk flavour: mawk / gawk / busybox)
  lines=$(grep -nE "$NOTE_RE" "$F" | cut -d: -f1 | awk -v del=" $* " 'index(del, " " NR " ") { printf " %s", $0 }')
  tmp=$(mktemp "$F.XXXXXX") || return 1
  awk -v del="$lines " '!index(del, " " NR " ")' "$F" >"$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$F" || { rm -f "$tmp"; return 1; }
  n=$#
  [ -n "$ip" ] && ab_timeline "$ip" nota "$n nota(s) borrada(s) de notes.md"
  echo "[+] $n nota(s) borrada(s) de $dest"
}

confirm_tty() {   # confirm_tty <question> [word]  (word: must be typed exactly)
  local a
  [ -t 0 ] || return 1
  if [ -n "${2:-}" ]; then read -r -p "$1 Escribe $2 para confirmar: " a; [ "$a" = "$2" ]
  else read -r -p "$1 [s/N] " a; [[ $a =~ ^[sSyY] ]]; fi
}

rm_cli() {
  local yes=0 max nums=() a
  for a; do [ "$a" = --yes ] && yes=1 || nums+=("$a"); done
  max=$(count)
  [ "$max" -gt 0 ] || { echo "(sin notas en $dest)"; return 0; }
  mapfile -t nums < <(parse_nums "$max" "${nums[@]}") && [ ${#nums[@]} -gt 0 ] || return 1
  if [ "$yes" = 0 ] && [ -t 0 ]; then
    notes | awk -v d=" ${nums[*]} " 'index(d, " " NR " ") { printf "%3d  %s\n", NR, substr($0, 3) }'
    confirm_tty "¿Borrar ${#nums[@]} nota(s)?" || { echo "cancelado"; return 0; }
  fi
  delete_notes "${nums[@]}"
}

rm_all_cli() {
  local max
  max=$(count)
  [ "$max" -gt 0 ] || { echo "(sin notas en $dest)"; return 0; }
  if [ "${1:-}" != --yes ]; then
    if [ -t 0 ]; then confirm_tty "¿Borrar TODAS las notas ($max) de $dest?" BORRAR || { echo "cancelado"; return 0; }
    else echo "[!] sin terminal: usa --rm-all --yes" >&2; return 1; fi
  fi
  # shellcheck disable=SC2046
  delete_notes $(seq 1 "$max")
  [ -n "$ip" ] && ab_timeline "$ip" nota "todas las notas borradas ($max)"
  return 0
}

# ---------------------------------------------------------------- popups
gui_confirm() {   # gui_confirm <question> [word]
  local a
  if ab_has rofi; then
    if [ -n "${2:-}" ]; then
      a=$(printf '' | rofi -dmenu -p "Escribe $2" -mesg "$(ab_markup_escape "$1")" \
            -theme-str 'listview {lines: 0;}' 2>/dev/null) || return 1
      [ "$a" = "$2" ]
    else
      a=$(printf 'No\nSí, borrar\n' | rofi -dmenu -i -no-custom -format i -p "Confirmar" \
            -mesg "$(ab_markup_escape "$1")" 2>/dev/null) || return 1
      [ "$a" = 1 ]
    fi
  elif ab_has yad; then
    if [ -n "${2:-}" ]; then
      a=$(yad --entry --title "Confirmar" --text "$1\nEscribe $2 para confirmar" 2>/dev/null) || return 1
      [ "$a" = "$2" ]
    else
      yad --question --title "Confirmar" --text "$1" --button "No:1" --button "Sí, borrar:0" 2>/dev/null
    fi
  else
    return 1
  fi
}

manage() {
  local max sel n rc
  local -a nums=()
  max=$(count)
  if [ "$max" -eq 0 ]; then ab_notify "No hay notas en $dest" "Notas"; return 0; fi
  if ab_has rofi; then
    # row 0 = delete all; rows 1..max = notes. Shift+Enter marks several, Enter deletes.
    sel=$({ printf '󰆴 Borrar TODAS las notas (%s)\n' "$max"; notes | cut -c3-; } |
          rofi -dmenu -i -no-custom -multi-select -format i -p "󰆴 Borrar" \
            -mesg "$(ab_markup_escape "$(where) · Shift+Enter marca varias · Enter borra")" 2>/dev/null) || return 0
    mapfile -t nums <<<"$sel"
  elif ab_has yad; then
    sel=$(notes | cut -c3- | awk '{ print "FALSE"; print NR; print }' |
          yad --list --checklist --title "Notas — $(where)" --column "" --column "#" --column "Nota" \
              --print-column 2 --separator '' --width 760 --height 420 \
              --button "Borrar TODAS:2" --button "Borrar marcadas:0" --button "Cerrar:1" 2>/dev/null)
    rc=$?
    case "$rc" in
      2) nums=(0) ;;
      0) mapfile -t nums < <(awk 'NF' <<<"$sel") ;;
      *) return 0 ;;
    esac
  else
    ab_notify "Instala rofi o yad (o usa: note --list / note --rm N)" "Notas"; return 1
  fi
  for n in "${nums[@]}"; do
    if [ "$n" = 0 ]; then
      gui_confirm "Vas a borrar TODAS las notas ($max) de $dest. No se puede deshacer." BORRAR || return 0
      # shellcheck disable=SC2046
      delete_notes $(seq 1 "$max") >/dev/null
      [ -n "$ip" ] && ab_timeline "$ip" nota "todas las notas borradas ($max)"
      ab_notify "Borradas todas las notas ($max) de $dest" "Notas"
      return 0
    fi
  done
  local -a valid=()
  for n in "${nums[@]}"; do [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= max )) && valid+=("$n"); done
  [ ${#valid[@]} -gt 0 ] || return 0
  gui_confirm "¿Borrar ${#valid[@]} nota(s) de $dest?" || return 0
  delete_notes "${valid[@]}" >/dev/null
  ab_notify "${#valid[@]} nota(s) borrada(s) de $dest" "Notas"
}

# ask → prints the text; exit 3 = "view / delete" chosen
ask() {
  local w out rc
  w=$(where)
  if ab_has rofi; then
    out=$(printf '' | rofi -dmenu -p "󰠮 Nota" -kb-custom-1 'Alt+d' \
          -mesg "$(ab_markup_escape "$w · Enter guarda · Alt+d ver / borrar notas ($(count))")" \
          -theme-str 'listview {lines: 0;} window {width: 640px;}' 2>/dev/null); rc=$?
    [ "$rc" = 10 ] && return 3
    [ "$rc" = 0 ] || return 1
  elif ab_has yad; then
    out=$(yad --entry --title "Nota rápida" --text "$w" --width 520 \
          --button "Ver / borrar notas:3" --button "Cancelar:1" --button "Guardar:0" 2>/dev/null); rc=$?
    [ "$rc" = 3 ] && return 3
    [ "$rc" = 0 ] || return 1
  else
    ab_notify "Instala rofi o yad para las notas rápidas (o usa: note <texto>)"
    return 1
  fi
  printf '%s\n' "$out"
}

add() {
  local text=$1 stamp
  text=${text//[$'\r\n']/ }
  text="${text#"${text%%[![:space:]]*}"}"; text="${text%"${text##*[![:space:]]}"}"
  [ -n "$text" ] || return 0
  stamp=$(date '+%Y-%m-%d %H:%M')
  if [ -n "$ip" ]; then
    ab_target_dir "$ip" >/dev/null
  else
    mkdir -p "$(dirname "$F")" && chmod 700 "$(dirname "$F")" 2>/dev/null
    [ -s "$F" ] || printf '# Inbox\n\nNotas sin target (quick-note / Super+Alt+n).\n\n' >"$F"
  fi
  # a note always starts on its own line
  [ -s "$F" ] && [ -n "$(tail -c1 "$F")" ] && printf '\n' >>"$F"
  printf -- '- [%s] %s\n' "$stamp" "$text" >>"$F" || { ab_notify "No pude escribir en $dest"; return 1; }
  chmod 600 "$F" 2>/dev/null || true
  [ -n "$ip" ] && ab_timeline "$ip" nota "nota añadida a notes.md (${#text} caracteres)"
  echo "[+] nota → $dest"
  ab_notify "Guardada en $dest" "Nota"
}

case "${1:-}" in
  --list|-l)   list ;;
  --path)      echo "$F" ;;
  --rm|-r)     shift; rm_cli "$@" || exit 1 ;;
  --rm-all)    shift; rm_all_cli "$@" || exit 1 ;;
  --manage|-m) manage ;;
  -h|--help)   sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' ;;
  --)          shift; add "$*" || exit 1 ;;
  "")          text=$(ask); rc=$?
               if [ "$rc" = 3 ]; then manage; elif [ "$rc" = 0 ]; then add "$text" || exit 1; fi ;;
  -?*)         echo "[!] opción desconocida: $1 (note --help; para texto que empieza por '-': note -- texto)" >&2; exit 2 ;;
  *)           add "$*" || exit 1 ;;
esac
exit 0
