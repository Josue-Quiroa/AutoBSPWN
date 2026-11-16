#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — choose the picom profile for this machine (used by bspwmrc and Install.sh).
#   picom-profile.sh             candidate configs, best first (one path per line)
#   picom-profile.sh --explain   one-line summary (version · VM · profile)
#
#   picom >= 12 (Parrot 7, Kali) → picom-rules.conf     animations + dual_kawase blur (glx)
#   picom 10/11 (Parrot 6)       → picom.conf           fade + dual_kawase blur (glx), no animations
#   VM (any version)             → picom[-rules]-vm.conf xrender, fade only (no blur/animations)
#   Physical machines also list the -vm profile second: bspwmrc falls back to it if glx fails.
#
# Override: ~/.config/picom/profile with "full" (force the glx profile, e.g. VMware with 3D
# acceleration) or "lite" (force the VM profile). For tests: AB_PICOM_VERSION=10 AB_IS_VM=0|1.
DIR="${AB_PICOM_DIR:-$HOME/.config/picom}"

picom_major() {
  local v
  if [ -n "${AB_PICOM_VERSION:-}" ]; then
    v=$AB_PICOM_VERSION
  else
    command -v picom >/dev/null 2>&1 || { echo 0; return; }
    v=$(picom --version 2>/dev/null | head -n1)
  fi
  # "v10.2" / "v12.5" / "12" / "vgit-1a2b3" (git build)
  v=$(printf '%s\n' "$v" | sed -n 's/^v\{0,1\}\([0-9][0-9]*\).*/\1/p' | head -n1)
  echo "${v:-unknown}"
}

is_vm() {
  if [ -n "${AB_IS_VM:-}" ]; then
    [ "$AB_IS_VM" = 1 ]
    return
  fi
  local virt
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    virt=$(systemd-detect-virt --vm 2>/dev/null || true)
    [ -n "$virt" ] && [ "$virt" != none ] && return 0
  fi
  [ -r /sys/class/dmi/id/product_name ] \
    && grep -qiE 'VirtualBox|VMware|KVM|QEMU|Virtual Machine|Hyper-V|Xen|bochs' /sys/class/dmi/id/product_name 2>/dev/null
}

MAJOR=$(picom_major)
FAMILY=picom
# unknown (git builds print "vgit-…") → assume a recent picom
if [ "$MAJOR" = unknown ] || { [ "$MAJOR" -ge 12 ] 2>/dev/null; }; then FAMILY=picom-rules; fi

MODE=auto
[ -r "$DIR/profile" ] && MODE=$(tr -d '[:space:]' <"$DIR/profile")
VM=0
is_vm && VM=1

candidates() {
  case "$MODE" in
    full) printf '%s\n' "$DIR/$FAMILY.conf" "$DIR/$FAMILY-vm.conf" ;;
    lite) printf '%s\n' "$DIR/$FAMILY-vm.conf" ;;
    *)
      if [ "$VM" -eq 1 ]; then
        printf '%s\n' "$DIR/$FAMILY-vm.conf"
      else
        printf '%s\n' "$DIR/$FAMILY.conf" "$DIR/$FAMILY-vm.conf"
      fi ;;
  esac
}

if [ "${1:-}" = --explain ]; then
  first=$(candidates | head -n1)
  case "$(basename "$first")" in
    picom-rules.conf)    what="animaciones + blur (glx)" ;;
    picom.conf)          what="fade + blur (glx), sin animaciones (picom < 12)" ;;
    picom-rules-vm.conf) what="VM: xrender, fade, sin blur ni animaciones" ;;
    picom-vm.conf)       what="VM: xrender, fade, sin blur ni animaciones (picom < 12)" ;;
    *)                   what="?" ;;
  esac
  printf 'picom %s · VM=%s · modo=%s → %s (%s)\n' "$MAJOR" "$([ "$VM" -eq 1 ] && echo sí || echo no)" "$MODE" "$(basename "$first")" "$what"
  exit 0
fi
candidates
