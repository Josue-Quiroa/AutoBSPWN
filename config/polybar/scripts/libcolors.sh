# shellcheck shell=bash
# AutoBSPWN v3.3.0 — shared theme colors for polybar scripts (source me; do not execute).
# Reads ~/.config/polybar/colors.ini (spaces around '=' are optional).
# AB_PILL=1 (set in the module's exec line) = the module sits on a colored accent island
# (shade1..3): normal colors are swapped for on-shade / on-shade-dim so text stays readable.
_polycolor_raw() {
  local key="$1" def="$2" file="${HOME}/.config/polybar/colors.ini" val=
  [ -f "$file" ] && val=$(awk -F= -v k="$key" '
    {
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      gsub(/^[ \t]+|[ \t]+$/, "", $2)
      if ($1 == k) { print $2; exit }
    }' "$file")
  printf '%s\n' "${val:-$def}"
}
polycolor() {
  local key="${1:-}" def="${2:-#cdd6f4}"
  [ -n "$key" ] || { printf '%s\n' "$def"; return 0; }
  if [ "${AB_PILL:-0}" = 1 ]; then
    case "$key" in
      muted) _polycolor_raw on-shade-dim "$(_polycolor_raw muted "$def")"; return 0 ;;
      alert|warning) ;;
      *) _polycolor_raw on-shade "$def"; return 0 ;;
    esac
  fi
  _polycolor_raw "$key" "$def"
}
