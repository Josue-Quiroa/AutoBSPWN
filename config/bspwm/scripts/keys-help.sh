#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — cheat sheet built live from ~/.config/sxhkd/sxhkdrc (Super+F1 / Super+/).
# sxhkdrc convention:  "## Categoría"  ·  "# descripción" right above each chord.
#   keys-help.sh              rofi list (type to filter; Enter runs the action)
#   keys-help.sh --text       plain text      keys-help.sh --markdown   tables (ATAJOS.md)
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
RC="${SXHKD_RC:-$HOME/.config/sxhkd/sxhkdrc}"
[ -r "$RC" ] || { ab_notify "No encuentro $RC"; exit 1; }

# category <TAB> keys <TAB> description <TAB> command (first line)
parse() {
  awk '
    function pretty(k) {
      gsub(/super/, "Super", k); gsub(/shift/, "Shift", k); gsub(/ctrl/, "Ctrl", k)
      gsub(/alt/, "Alt", k);     gsub(/Return/, "Enter", k); gsub(/@space/, "Space", k)
      gsub(/space/, "Space", k); gsub(/Escape/, "Esc", k);   gsub(/bracketleft/, "[", k)
      gsub(/bracketright/, "]", k); gsub(/bracket\{left,right\}/, "{[,]}", k)
      gsub(/grave/, "`", k);     gsub(/slash/, "/", k);      gsub(/minus/, "-", k)
      gsub(/equal/, "=", k);     gsub(/comma/, "coma", k);   gsub(/period/, "punto", k)
      gsub(/~button3/, "Click derecho (escritorio)", k)
      return k
    }
    /^## /           { cat = substr($0, 4); next }
    /^#[^#]/ || /^#$/ { d = $0; sub(/^# ?/, "", d); next }
    /^[ \t]*$/       { next }
    /^[^ \t#]/       { keys = $0; want = 1; next }
    want && /^[ \t]/ { c = $0; sub(/^[ \t]+/, "", c)
                       printf "%s\t%s\t%s\t%s\n", (cat == "" ? "General" : cat), pretty(keys), (d == "" ? c : d), c
                       want = 0; d = ""; next }
  ' "$RC"
}

case "${1:-}" in
  --text)
    parse | awk -F'\t' '$1 != last { printf "\n[%s]\n", $1; last = $1 } { printf "  %-42s %s\n", $2, $3 }'
    exit 0 ;;
  --markdown)
    parse | awk -F'\t' '
      $1 != last { if (last != "") print ""; printf "### %s\n\n| Atajo | Acción |\n|---|---|\n", $1; last = $1 }
      { k = $2; gsub(/\|/, "\\|", k); printf "| `` %s `` | %s |\n", k, $3 }'
    exit 0 ;;
esac

ab_need_rofi
mapfile -t rows < <(parse)
pick=$(for r in "${rows[@]}"; do
         IFS=$'\t' read -r c k d _ <<<"$r"
         printf '%-18.18s  %-38s  %s\n' "$c" "$k" "$d"
       done | ab_menu "󰌌 Atajos" -format i -no-custom \
         -mesg "Escribe para filtrar · Enter ejecuta la acción · Esc cierra · lista completa: ~/ATAJOS.md" \
         -theme-str 'window {width: 960px;} listview {lines: 18;} * {font: "JetBrainsMono Nerd Font 10";}') || exit 0
[[ "$pick" =~ ^[0-9]+$ ]] || exit 0
IFS=$'\t' read -r _ _ _ cmd <<<"${rows[$pick]}"
# Chords with {a,b} expansions map to several commands: nothing sensible to run
[[ "$cmd" == *"{"* ]] && exit 0
setsid -f bash -c "$cmd" >/dev/null 2>&1
