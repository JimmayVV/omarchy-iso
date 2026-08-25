#!/usr/bin/env bash
# Runs inside the live-ISO chroot, from customize_airootfs.sh, once the live
# kernel and initramfs exist and before mkarchiso empties /boot.
#
# WHAT THIS IS FOR
# ----------------
# Windows-on-ARM laptops (Snapdragon X, 8cx Gen 3) boot with ACPI tables that
# Linux cannot drive the SoC from; the kernel needs the board's device tree,
# and the firmware hands over none. So the device tree has to reach the kernel
# from the boot medium. This wraps the live kernel and initramfs into a
# systemd-stub UKI that carries every Windows-on-ARM device tree the kernel
# package ships as `.dtbauto` sections, plus systemd's SMBIOS-ID-to-compatible
# database as `.hwids`. At boot the stub matches the machine's SMBIOS IDs
# against that database and installs the one matching device tree before the
# kernel starts. No board is named anywhere: support for a new laptop means
# "its device tree is in linux-aarch64 and its IDs are in systemd", both of
# them upstream contributions (JimmayVV/omarchy-iso#12).
#
# GRUB's `linux` command rejects a stub-wrapped image on arm64, so the entry
# in configs/grub/grub.cfg chainloads this file and passes the archiso
# arguments as EFI load options; the UKI therefore carries no .cmdline and
# grub.cfg stays the single place those arguments are written.
#
# This is the only point in the build where both inputs exist: the kernel
# image appears when packages install, and mkarchiso deletes everything in
# /boot right after customize_airootfs.sh. The result reaches the ISO through
# builder/patches/archiso-copy-boot-efi.patch.
set -euo pipefail

kernel=/boot/vmlinuz-linux-aarch64
initrd=/boot/initramfs-linux-aarch64.img
uki=/boot/omarchy-live.efi
hwids=/usr/lib/systemd/boot/hwids/aa64

for f in "$kernel" "$initrd"; do
  if [[ ! -s $f ]]; then
    echo "live-uki: $f is missing; customize_airootfs.sh should have produced it" >&2
    exit 1
  fi
done
if ! command -v ukify >/dev/null; then
  echo "live-uki: ukify not found; is systemd-ukify in configs/packages.aarch64?" >&2
  exit 1
fi
if [[ ! -d $hwids ]]; then
  echo "live-uki: no SMBIOS-ID database at $hwids (systemd >= 260 ships it)" >&2
  exit 1
fi

# The Windows-on-ARM SoCs in linux-aarch64's qcom/ tree, by device-tree name:
# Snapdragon X Elite/Plus (x1e*, x1p*, the hamoa* reference boards), X2 Elite
# (glymur*) and 8cx Gen 3 (sc8280xp*). The whole qcom/ directory is ~400
# files, well past the stub's section budget of ~96 (systemd/systemd#35943),
# so only these prefixes are wrapped. The *-el2 variants carry the same
# compatible as their base device tree and would make the match ambiguous;
# they exist for running the kernel at EL2, which none of this firmware does.
shopt -s nullglob
dtbs=()
for dtb in /boot/dtbs/qcom/x1*.dtb /boot/dtbs/qcom/hamoa*.dtb \
           /boot/dtbs/qcom/glymur*.dtb /boot/dtbs/qcom/sc8280xp*.dtb; do
  [[ $dtb == *-el2.dtb ]] && continue
  dtbs+=("$dtb")
done
if (( ${#dtbs[@]} == 0 )); then
  echo "live-uki: no Windows-on-ARM device trees under /boot/dtbs/qcom" >&2
  exit 1
fi
# Fail loudly rather than let a section be dropped where nobody looks.
if (( ${#dtbs[@]} > 90 )); then
  echo "live-uki: ${#dtbs[@]} device trees exceed the UKI section budget; narrow the prefixes" >&2
  exit 1
fi

args=()
for dtb in "${dtbs[@]}"; do
  args+=("--devicetree-auto=$dtb")
done

echo "live-uki: wrapping $kernel and $initrd with ${#dtbs[@]} device trees"
ukify build \
  --linux="$kernel" \
  --initrd="$initrd" \
  --hwids="$hwids" \
  "${args[@]}" \
  --output="$uki"

# Check the image before the build goes on: the ISO would otherwise build
# cleanly and the first boot entry fail on every Windows-on-ARM machine.
sections="$(ukify inspect "$uki")"
n_dtb="$(grep -c '^\.dtbauto:' <<<"$sections" || true)"
if ! grep -q '^\.hwids:' <<<"$sections"; then
  echo "live-uki: $uki has no .hwids section" >&2
  exit 1
fi
if (( n_dtb != ${#dtbs[@]} )); then
  echo "live-uki: $uki has $n_dtb .dtbauto sections, expected ${#dtbs[@]}" >&2
  exit 1
fi
echo "live-uki: $uki: $(stat -c %s "$uki") bytes, $n_dtb .dtbauto sections, .hwids present"
