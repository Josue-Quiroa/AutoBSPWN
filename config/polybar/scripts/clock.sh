#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — clock for polybar (click → calendar.sh). Format: AUTOBSPWN_CLOCK_FMT
# Default "%H:%M"; e.g. AUTOBSPWN_CLOCK_FMT="%a %d · %I:%M %p" in ~/.xprofile
printf '󰥔 %s\n' "$(date +"${AUTOBSPWN_CLOCK_FMT:-%H:%M}")"
