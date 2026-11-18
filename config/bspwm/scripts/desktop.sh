#!/usr/bin/env bash
# AutoBSPWN v3.4.0 — Super+1..0 / Super+Shift+1..0 with split or per-monitor desktops
#   desktop.sh focus <n>     go to desktop n        desktop.sh send <n>   move the window there (follow)
# desktops=split (default, ~/.config/autobspwn/state): I–X are spread over the monitors → n is
# global (Super+7 is desktop VII wherever it lives). desktops=each: I–X on every monitor → n is
# counted on the focused monitor (pre-3.4 behaviour).
n=${2:-}
[[ $n =~ ^([1-9]|10)$ ]] || exit 2
mode='split'
f="${AUTOBSPWN_STATE:-$HOME/.config/autobspwn/state}"
[ -r "$f" ] && [ "$(awk 'index($0, "desktops=") == 1 { v = substr($0, 10) } END { print v }' "$f")" = each ] && mode=each
if [ "$mode" = each ]; then sel="focused:^$n"; else sel="^$n"; fi
case "${1:-}" in
  focus) bspc desktop -f "$sel" ;;
  send)  bspc node -d "$sel" --follow ;;
  *) exit 2 ;;
esac
