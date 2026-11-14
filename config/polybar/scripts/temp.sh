#!/usr/bin/env bash
# Prefer x86_pkg_temp / k10temp / zenpower; skip dummy 0 readings.
# shellcheck source=/dev/null
. "$(dirname "$0")/libcolors.sh"

read_milli() {
  local z=$1 v
  [ -r "$z" ] || return 1
  v=$(cat "$z" 2>/dev/null) || return 1
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  [ "$v" -gt 1000 ] || return 1
  echo $((v / 1000))
}

t=
# Preferred thermal zone types
for zone in /sys/class/thermal/thermal_zone*; do
  [ -d "$zone" ] || continue
  typ=$(cat "$zone/type" 2>/dev/null || true)
  case "$typ" in
    x86_pkg_temp|k10temp|zenpower|cpu-thermal|cpu)
      t=$(read_milli "$zone/temp") && break
      ;;
  esac
done
# hwmon CPU-ish
if [ -z "$t" ]; then
  for n in /sys/class/hwmon/hwmon*; do
    [ -f "$n/name" ] || continue
    typ=$(cat "$n/name" 2>/dev/null || true)
    case "$typ" in
      k10temp|coretemp|zenpower|cpu|cpu_thermal|acpitz)
        t=$(read_milli "$n/temp1_input") && break
        ;;
    esac
  done
fi
# Any remaining thermal zone with a plausible value
if [ -z "$t" ]; then
  for z in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp1_input; do
    t=$(read_milli "$z") && break
  done
fi
[ -z "$t" ] && exit 0
alert=$(polycolor alert '#f38ba8')
warn=$(polycolor warning '#fab387')
ok=$(polycolor success '#a6e3a1')
if [ "$t" -ge 80 ]; then echo "%{F$alert}󰔓%{F-} ${t}°"
elif [ "$t" -ge 65 ]; then echo "%{F$warn}󰔐%{F-} ${t}°"
else echo "%{F$ok}󰔏%{F-} ${t}°"
fi
