#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — clock for polybar (click → calendar.sh). Format: AUTOBSPWN_CLOCK_FMT
# Default "%a %d %b · %H:%M"; e.g. AUTOBSPWN_CLOCK_FMT="%H:%M" in ~/.xprofile
# AB_BAR_COMPACT=1 (narrow monitor, set by launch.sh): time only
if [ "${AB_BAR_COMPACT:-0}" = 1 ]; then def="%H:%M"; else def="%a %d %b · %H:%M"; fi
printf '󰥔 %s\n' "$(date +"${AUTOBSPWN_CLOCK_FMT:-$def}")"
