#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — calendar popup under the polybar clock (click again to close).
# yad --calendar (Parrot 6/7, Kali) → gsimplecal → floating terminal with `cal -3`.
# Idea from yoodreamer/AutoBSPWM (clock click → calendar); own implementation.
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"

CLASS=autobspwn-cal
W=300; H=260; BAR=${AUTOBSPWN_BAR_HEIGHT:-30}

# Toggle: a second click closes it
if pkill -u "$(id -u)" -f -- "--class=$CLASS" 2>/dev/null; then exit 0; fi
if pkill -u "$(id -u)" -x gsimplecal 2>/dev/null; then exit 0; fi

# Centered under the mouse (the clock), kept inside the screen
x=960; sw=1920
if ab_has xdotool; then
  eval "$(xdotool getmouselocation --shell 2>/dev/null | grep -E '^(X|Y)=')" 2>/dev/null || true
  x=${X:-960}
  sw=$(xdotool getdisplaygeometry 2>/dev/null | awk '{print $1}')
  sw=${sw:-1920}
fi
px=$(( x - W / 2 )); [ "$px" -lt 8 ] && px=8
[ $(( px + W + 8 )) -gt "$sw" ] && px=$(( sw - W - 8 ))
py=$(( BAR + 8 ))

if ab_has yad; then
  GTK_THEME=${GTK_THEME:-Adwaita:dark} yad --calendar --class="$CLASS" --name="$CLASS" \
    --title="Calendario" --undecorated --skip-taskbar --on-top --close-on-unfocus \
    --no-buttons --show-weeks --borders=10 --width="$W" --height="$H" \
    --posx="$px" --posy="$py" >/dev/null 2>&1 &
  exit 0
fi

if ab_has gsimplecal; then
  cfg="$HOME/.config/gsimplecal/config"
  if [ ! -f "$cfg" ]; then
    mkdir -p "${cfg%/*}"
    printf 'show_calendar = 1\nshow_timezones = 0\nmark_today = 1\nshow_week_numbers = 1\nclose_on_unfocus = 1\nmainwindow_decorated = 0\nmainwindow_keep_above = 1\nmainwindow_skip_taskbar = 1\nmainwindow_position = mouse\n' >"$cfg"
  fi
  gsimplecal >/dev/null 2>&1 &
  exit 0
fi

ab_term -o initial_window_width=34c -o initial_window_height=11c -- \
  bash -c 'cal -3 2>/dev/null || cal; read -r -s -n1'
