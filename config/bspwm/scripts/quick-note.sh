#!/usr/bin/env bash
# AutoBSPWN v3.4.0 — quick note (Super+Alt+n · or `note <texto>` in a terminal)
#   quick-note.sh                 popup (rofi, yad as fallback): one line
#   quick-note.sh <texto…>        no popup
# Active target → appended to ~/targets/<ip>/notes.md as "- [fecha hora] texto" (and a line in
# its timeline.tsv: only that a note was added, never the text). No target → ~/notes/inbox.md.
# The text is only ever written with printf: nothing in it (or in the target name) is executed.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

INBOX="${AUTOBSPWN_NOTES:-$HOME/notes}/inbox.md"

ip=$(ab_focus_ip 2>/dev/null || true)
ab_is_ipv4 "$ip" || ip=''
name=$(ab_focus_name 2>/dev/null || true)

ask() {
  local where
  if [ -n "$ip" ]; then where="${name:+$name · }$ip → notes.md"; else where="sin target → ~/notes/inbox.md"; fi
  if ab_has rofi; then
    printf '' | rofi -dmenu -p "󰠮 Nota" -mesg "$(ab_markup_escape "$where")" \
      -theme-str 'listview {lines: 0;} window {width: 640px;}' 2>/dev/null
  elif ab_has yad; then
    yad --entry --title "Nota rápida" --text "$where" --width 520 2>/dev/null
  else
    ab_notify "Instala rofi o yad para las notas rápidas (o usa: note <texto>)"
    return 1
  fi
}

if [ $# -gt 0 ]; then text="$*"; else text=$(ask) || exit 0; fi
text=${text//[$'\r\n']/ }
text="${text#"${text%%[![:space:]]*}"}"; text="${text%"${text##*[![:space:]]}"}"
[ -n "$text" ] || exit 0

stamp=$(date '+%Y-%m-%d %H:%M')
if [ -n "$ip" ]; then
  f="$(ab_target_dir "$ip")/notes.md"
else
  f=$INBOX
  mkdir -p "$(dirname "$f")" && chmod 700 "$(dirname "$f")" 2>/dev/null
  [ -s "$f" ] || printf '# Inbox\n\nNotas sin target (quick-note / Super+Alt+n).\n\n' >"$f"
fi
dest=${f/#"$HOME"/\~}
# a note always starts on its own line
[ -s "$f" ] && [ -n "$(tail -c1 "$f")" ] && printf '\n' >>"$f"
printf -- '- [%s] %s\n' "$stamp" "$text" >>"$f" || { ab_notify "No pude escribir en $dest"; exit 1; }
chmod 600 "$f" 2>/dev/null || true
[ -n "$ip" ] && ab_timeline "$ip" nota "nota añadida a notes.md (${#text} caracteres)"
echo "[+] nota → $dest"
ab_notify "Guardada en $dest" "Nota"
exit 0
