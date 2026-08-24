# Reproducing PR omacom-io/omarchy-iso#121 on a native aarch64 host

Research for [JimmayVV/omarchy-iso#7](https://github.com/JimmayVV/omarchy-iso/issues/7)
(map: [#1](https://github.com/JimmayVV/omarchy-iso/issues/1)). Read on 2026-08-24.

**Question.** What exactly is needed to reproduce upstream PR #121's aarch64 ISO build
on the G1q's WSL2 (docker, native arm64), and what is the status / chosen workaround for
each of the three blockers the PR lists as out of scope?

**Answer in one line.** The PR builds as-is on `menci/archlinuxarm` once (a) one function
in the vendored archiso v87 `mkarchiso` is patched to drop seven GRUB modules that do not
exist for `arm64-efi`, and (b) an aarch64 `[omarchy]` repo is mounted in (ticket #6). The
`pkgbase` gap (ALARM #2215) does not block the ISO build; it blocks the *installed* system
from ever getting an initramfs or Limine entry, and no upstream fix is coming soon.

---

## Pins at time of reading

| What | Value |
|---|---|
| PR #121 head | `adf5a1f2bf2f11a963a8ec669ccbd872091a98d9` (branch `oceanapplications:aarch64-build-system`, draft, 7 commits, updated 2026-08-24T15:52Z) |
| PR base / merge-base | `quattro` @ `268bac16d351a21d867e37565738f458b11cb06c` (= current `origin/quattro` HEAD; the PR is rebased on tip) |
| archiso submodule (both `quattro` and the PR branch) | `424e78130db2af6c1ceb55b442d7914b1109ff2b` = tag **v87** (2025-10-29) |
| archiso upstream | v88 `52bf735f` (2026-03-25), v89 `a38bfd14` (2026-07-25); default branch is `master`, not `main` (`.gitmodules` says `branch = main`, harmless) |
| Arch `archiso` package (what the x86 build actually runs) | 89-1 (2026-07-27) |
| ALARM `linux-aarch64` (master PKGBUILD) | 7.2-2, **no** `pkgbase`/`vmlinuz` install lines |
| ALARM `grub` (aarch64/core) | 2:2.14-1.1, 490 `arm64-efi` modules |
| archlinuxarm/PKGBUILDs#2215 | open draft PR, head `173bd4173de67c59908201e71180bfc964fa84b3` |

The PR head is fetchable in the main clone as `oceanapplications/aarch64-build-system`
(remote added as part of this ticket).

## What the PR changes (the parts that matter for reproduction)

Files: `builder/build-iso.sh`, `builder/build-omarchy-packages.sh`,
`configs/aarch64/{customize_airootfs.sh,linux.preset,zz-aarch64-live.conf}` (new),
`configs/packages.aarch64` (new), `configs/profiledef.sh`,
`configs/airootfs/root/{.automated_script.sh,configurator}`,
`configs/airootfs/usr/share/omarchy-iso/orchestrator/{context.py,phases_impl.py}`.

- Everything keys off `uname -m` inside the container. There is **no `--arch` flag**; the
  plan's `bin/omarchy-iso-make --arch` was not implemented. `bin/omarchy-iso-make` is
  **untouched** and still runs `docker run ... archlinux/archlinux:latest`, whose `latest`
  tag has only an `amd64` manifest. On an arm64 docker host that either fails to pull or
  runs under emulation. So the entrypoint needs a local edit (below).
- archiso install: `pacman -S archiso` is tried first; ALARM has no such package (404 on
  archlinuxarm.org), so it falls back to `cp -r /archiso /tmp/archiso-src && make -C
  /tmp/archiso-src PREFIX=/usr install-scripts install-profiles`. **`/usr/bin/mkarchiso`
  is therefore the vendored v87 script, and `/tmp/archiso-src/archiso/mkarchiso` is the
  place to patch before `make install`.**
- On aarch64 a filtered pacman config is staged at `/tmp/pacman-online-$MIRROR.conf`
  (drops `[multilib]`, `[arch-mact2]`, and the x86-only `Server=` lines in core/extra so
  ALARM's mirrorlist is used). The `[omarchy]` section is copied verbatim -- that is where
  the local-repo substitution goes.
- `configs/packages.aarch64` is a pruned copy of releng's `packages.x86_64`; because
  `cp -r /configs/*` runs after the releng seed, it simply overrides. Blocker (2) is
  already solved inside the PR for our purposes.
- `OMARCHY_ARCH_DROP` removes packages with no aarch64 build from all four lists (live,
  omarchy-base, omarchy-other, archinstall); `quickshell-git -> quickshell`, `mise ->
  mise-bin`.
- Live kernel is `linux-aarch64`; `customize_airootfs.sh` copies `/boot/Image` to
  `/boot/vmlinuz-linux-aarch64`, writes an archiso preset, runs `mkinitcpio -p
  linux-aarch64`, and fails the build if no initramfs appears. It tolerates mkinitcpio's
  non-zero exit (memdisk hook wants `phram`/`memdiskfind`, absent on ARM).
- airootfs is `xz -Xbcj arm` on aarch64 because ALARM's kernel lacks
  `CONFIG_SQUASHFS_ZSTD`.
- The PR author's stated test: built natively on ALARM (kernel 7.2.0-1), 3.4 GB ISO. Since
  the PR's own "out of scope" says `grub-mkstandalone` aborts without an archiso change, the
  author must have carried that patch locally; it is not in the diff.

## The three blockers

### (1) archiso `_make_bootmode_uefi.grub()` GRUB module list -- must carry a patch

**Status: unfixed upstream.** The function is byte-identical between v87 (our pin) and v89
on the module list; v89 only reworked how the FAT image is filled. No open or merged MR
touches it. Related open MRs that do *not* address it:

- [!449](https://gitlab.archlinux.org/archlinux/archiso/-/merge_requests/449) "mkarchiso: add
  stubble for aarch64 profiles" (clover, 2026-08-12) -- adds releng `packages.aarch64` and a
  `ukify --devicetree-auto` step for Qualcomm DTBs. Relevant to the map's DTB decision, not
  to GRUB.
- [!462](https://gitlab.archlinux.org/archlinux/archiso/-/merge_requests/462) "mkarchiso: add
  AArch64 boot compatibility parameters" (clover, 2026-08-12) -- per-arch `kernel_params`;
  releng sets `kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"` for
  Snapdragon. Worth copying into our `grub.cfg` when we get to the boot-chain ticket.
- [!464](https://gitlab.archlinux.org/archlinux/archiso/-/merge_requests/464) merged
  2026-08-02: releng `-Xbcj x86,arm64`. Cosmetic for us (the PR sets its own).

Both open MRs come from the Arch Ports aarch64 project (Arch's own, in-progress aarch64 port
with `linux`, `linux-dtbs`, `stubble` packages). Those are Arch-Ports package names, not
ALARM's, so even if merged they do not replace the PR's `packages.aarch64`.

**Verified missing set.** Against ALARM `grub 2:2.14-1.1` (`core.files` db) and GRUB's
`Makefile.core.def`, exactly seven of the 55 hardcoded modules have no `arm64-efi` build:

```
at_keyboard keylayouts            # enable = x86
usb usbserial_common usbserial_ftdi usbserial_pl2303 usbserial_usbdebug   # enable = usb (x86 PCI)
```

Everything else the list names exists (`tpm`, `serial`, `efifwsetup`, `all_video`, `video`,
`zstd`, ...). ALARM's grub also ships `/usr/share/grub/sbat.csv` and the `en@quot` locale
that `grub-mkstandalone` is passed, so the module list is the only failure.

**Chosen workaround: carry a patch, applied to the copied source before `make install`.**
The PR's suggested self-maintaining fix, gated to aarch64 so the x86_64 binary stays
byte-identical:

```diff
--- a/archiso/mkarchiso
+++ b/archiso/mkarchiso
@@ _make_bootmode_uefi.grub() @@
                  search_fs_file search_fs_uuid search_label serial sleep tpm udf usb usbserial_common usbserial_ftdi \
                  usbserial_pl2303 usbserial_usbdebug video xfs zstd)
+    # Keep only modules that exist for this target. at_keyboard, keylayouts and usb*
+    # are x86-only and abort grub-mkstandalone on arm64-efi.
+    if [[ "$arch" == 'aarch64' ]]; then
+        local _m _present=()
+        for _m in "${grubmodules[@]}"; do
+            [[ -e "/usr/lib/grub/${grub_target}/${_m}.mod" ]] && _present+=("$_m")
+        done
+        grubmodules=("${_present[@]}")
+    fi
     grub-mkstandalone -O "$grub_target" \
```

Wiring in `builder/build-iso.sh`, inside the submodule-fallback branch:

```bash
  cp -r /archiso /tmp/archiso-src
  patch -p1 -d /tmp/archiso-src < /builder/patches/archiso-grub-modules-arm64.patch
  make -C /tmp/archiso-src PREFIX=/usr install-scripts install-profiles
```

(`/builder` is already a read-only mount; `patch` is in `base-devel`.) Alternatives
considered: a `sed -i` on `/usr/bin/mkarchiso` after install (works, but a regex over a
55-token line is brittle); pinning the submodule to a fork carrying the change (heavier,
and we would then own the v87->v89 rebase too). A patch file is the cheapest to keep across
rebases of the PR branch, and drops out cleanly if upstream ever merges an equivalent. Not
worth opening the archiso MR ourselves yet per the map's no-upstream-contact rule.

Two other v87 details checked and found harmless on aarch64: `efiboot_files` includes
`edk2-shell`'s `Shell_Full.efi` unconditionally, but `_make_efibootimg` runs `du ...
2>/dev/null` so a missing file only under-sizes by zero; the copy is `[[ -e ]]`-guarded.

### (2) releng ships no `packages.aarch64` -- already handled by the PR

**Status:** still true of v87 and v89; !449 would add one but with Arch-Ports package
names. **Workaround:** none needed beyond the PR -- `configs/packages.aarch64` overrides the
seeded profile. If the PR branch ever drops it, the fallback is a one-liner in
`build-iso.sh` (`cp packages.x86_64 packages.aarch64` + the same drop list).

### (3) ALARM kernels omit `usr/lib/modules/<ver>/pkgbase` -- no fix coming; plan around it

**Status: open, and the maintainer's only response is a policy pointer.**
[archlinuxarm/PKGBUILDs#2215](https://github.com/archlinuxarm/PKGBUILDs/pull/2215) (opened
2026-08-24 12:17Z by oceanapplications, draft) adds to `linux-aarch64`, `linux-aarch64-rc`
and `linux-armv7` the two lines Arch's `linux` has:

```bash
install -Dm644 arch/arm64/boot/Image "$modulesdir/vmlinuz"
echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"
```

graysky2 replied at 18:10Z with only a link to `CONTRIBUTING.md`, whose rules the PR
violates: **one package per PR**, `pkgrel` bump required, must be built in a clean chroot on
every supported arch ("PRs that fail to meet these requirements may be summarily closed").
Expect it to stall or be closed until resubmitted as three PRs. Do not plan on it landing.

**Why it matters (verified chain).** Three things key on that file after `pacstrap`:

1. `mkinitcpio`'s `90-mkinitcpio-install.hook` triggers on `usr/lib/modules/*/vmlinuz`, and
   `/usr/share/libalpm/scripts/mkinitcpio` loops `for pkgbase_path in
   /usr/lib/modules/*/pkgbase` (lines 41-44) to create presets and build images.
2. `limine-mkinitcpio-hook` (omarchy-pkgs, wraps Zesko's `limine-entry-tool` 1.37.1):
   `90-mkinitcpio-install.hook` line 18 `Target = usr/lib/modules/*/pkgbase`, and
   `60-limine-mkinitcpio-remove-pre.hook` likewise. This is what writes Limine entries.
3. PR #121's `detect_kernel()` returns `linux-aarch64` and `validate_boot()` looks for that
   pkgbase's artifacts.

Without the file, pacman's hook Targets never match (they match the *package's* file list,
not the filesystem), so nothing runs: no initramfs, no `limine.conf` entry, silent success.

**The live ISO is unaffected** -- `customize_airootfs.sh` builds the live initramfs by hand.
This is purely an install-time and post-install-upgrade problem.

**Workarounds, in order of durability:**

- **A. Rebuild `linux-aarch64` ourselves with the #2215 lines, in the aarch64 `[omarchy]`
  repo (ticket #6's build).** Durable: every future kernel upgrade keeps working. Cost: a
  kernel build on the G1q. The map already expects a Snapdragon kernel/DTB layer, so the
  first custom kernel we ship gets `pkgbase` for free -- fold the two lines into whatever
  PKGBUILD that ticket produces. *Recommended.*
- **B. One-shot fixup in the installer** (an orchestrator phase after pacstrap, before the
  bootloader phase): `for d in /mnt/usr/lib/modules/*/; do echo linux-aarch64 >"$d/pkgbase";
  cp /mnt/boot/Image "$d/vmlinuz"; done`, then `arch-chroot /mnt mkinitcpio -P` and the
  Limine hook's `limine-update`. Unblocks the *first* install test only; the next
  `pacman -Syu` that brings a new kernel reinstates the silent no-boot. Acceptable for the
  live-USB / first-install milestone with a loud comment; not shippable.
- **C. A shim package** (e.g. `omarchy-alarm-pkgbase-shim`) with a `PostTransaction` hook on
  `Target = usr/lib/modules/*/` ordered before `90-*`, writing the two files and then
  invoking `mkinitcpio -P` + `limine-update` itself (it cannot re-trigger the later hooks).
  Works without a kernel rebuild but duplicates hook logic; only if A proves too slow.

Note the ticket's suggestion of writing `pkgbase` in `customize_airootfs.sh`: that script
runs in the *live* chroot, so it can fix the live image (not needed) but not the target
system. The target-side hook point is `phases_impl.py`'s post-pacstrap phase (option B) or
the package itself (A/C).

## Step-by-step reproduction (G1q, WSL2, native arm64 docker)

Assumes a WSL2 distro with a working docker engine (Docker Desktop's WSL2 backend on
Windows-on-ARM is fine; the container runs natively, no binfmt). Needs ~20 GB free
(offline mirror cache + 3.4 GB ISO), `git`, `sudo`. `gum` only if you want the boot offer.

1. **Check out the PR branch with the submodule.**
   ```bash
   git clone https://github.com/JimmayVV/omarchy-iso.git ~/personal/omarchy-iso && cd ~/personal/omarchy-iso
   git remote add oceanapplications https://github.com/oceanapplications/omarchy-iso.git
   git fetch oceanapplications aarch64-build-system
   git checkout -b aarch64-build-system adf5a1f2bf2f11a963a8ec669ccbd872091a98d9
   git submodule update --init          # archiso @ 424e7813 (v87)
   ```
2. **Carry the GRUB patch.** Add `builder/patches/archiso-grub-modules-arm64.patch` (diff
   above) and the three-line wiring in `build-iso.sh`'s submodule-fallback branch.
3. **Point the build at an arm64 image.** In `bin/omarchy-iso-make`, replace
   `archlinux/archlinux:latest` with `menci/archlinuxarm:base-devel` and add
   `--platform linux/arm64` to `DOCKER_ARGS`. (`archlinuxarm/archlinuxarm` does not exist on
   Docker Hub; `menci/archlinuxarm` is rebuilt daily by GitHub Actions -- last push
   2026-08-24 -- with `linux/arm64`, `amd64`, `arm/v7`, `riscv64` manifests, tags `base` and
   `base-devel`. Its README says the pacman local-signing key is stripped, like the official
   Arch image; `build-iso.sh` already runs `pacman-key --init` and installs
   `archlinux-keyring`, which ALARM core also carries (20260727-1). If the first `pacman -Sy`
   fails on signature trust, add `pacman-key --populate archlinuxarm` after `--init`; that is
   the one step not verifiable without running it.)
4. **Provide the aarch64 `[omarchy]` repo** (ticket #6). `pkgs.omarchy.org/stable/aarch64`
   404s. Hook point: `configs/pacman-online-<mirror>.conf` line 30, `Server =
   https://pkgs.omarchy.org/stable/$arch`, with `SigLevel = Optional TrustAll` -- so an
   unsigned local repo is enough. Mount it and substitute the URL in the PR's aarch64 awk
   stage (or a sed right after it):
   ```bash
   # bin/omarchy-iso-make
   DOCKER_ARGS+=(-v "$HOME/omarchy-repo-aarch64:/omarchy-repo:ro")
   # builder/build-iso.sh, after the awk that writes $PACMAN_ONLINE_CONF
   sed -i 's|^Server = https://pkgs.omarchy.org/.*|Server = file:///omarchy-repo|' "$PACMAN_ONLINE_CONF"
   ```
   The repo must contain at least: `omarchy-keyring` (installed by name before anything
   else), `omarchy`, `omarchy-settings`, `omarchy-nvim`, `ttfx`, `limine-mkinitcpio-hook`,
   `limine-snapper-sync`, plus every other `[omarchy]`-only name in `omarchy-base.packages` /
   `omarchy-other.packages` that survives `OMARCHY_ARCH_DROP`. `--local-source` builds only
   the three `omarchy*` packages, so it does not replace this.
5. **Build.**
   ```bash
   NO_BOOT_OFFER=1 ./bin/omarchy-iso-make --keep-pkg-cache
   ```
   `--keep-pkg-cache` avoids the interactive `sudo rm -rf /var/cache/pacman/pkg/*` (which is
   also pointless on a non-Arch WSL distro). Output: `release/omarchy-*-aarch64-quattro.iso`.
   The script's `lint_file_permissions` runs `git ls-files`, so run it from the checkout.
6. **Verify the GRUB patch took** before burning anything:
   ```bash
   xorriso -indev release/omarchy-*-aarch64-*.iso -ls /EFI/BOOT/     # expect BOOTAA64.EFI
   ```
7. **Boot smoke test** (on the x86 box; `bin/omarchy-iso-boot` is x86-only, PR did not
   change it):
   ```bash
   qemu-system-aarch64 -M virt -cpu max -m 4G -bios /usr/share/edk2/aarch64/QEMU_EFI.fd \
     -device virtio-gpu-pci -device qemu-xhci -device usb-kbd -cdrom release/omarchy-*-aarch64-*.iso
   ```
   Then live USB on the G1q per the map's standing preference. Expect an install to
   "succeed" and not boot until blocker (3) is handled (option B is the quickest way to see
   past it).

## Side findings for the map

- `bin/omarchy-iso-boot`, `bin/omarchy-vm`, `bin/omarchy-iso-release` and the nightly
  workflow remain x86-only; the plan's sections 9-11 were not implemented in #121.
- The PR's `configs/packages.aarch64` still lists `amd-ucode` and `b43-fwcutter`; both are
  removed later by the drop list, so harmless.
- The Arch Ports aarch64 project (`gitlab.archlinux.org/archlinux/ports/aarch64`) is an
  alternative base distro with `stubble`/DTB tooling already in archiso MRs. The map chose
  ALARM; worth a line in the boot-chain ticket, not a reversal.

## Sources

- PR: https://github.com/omacom-io/omarchy-iso/pull/121 (`gh pr view/diff 121`, head `adf5a1f`)
- Local: `bin/omarchy-iso-make`, `builder/build-iso.sh`, `.gitmodules`, `plans/aarch64-support.md` @ `268bac1`
- archiso `mkarchiso` at `424e7813` (v87) and `v89`: https://gitlab.archlinux.org/archlinux/archiso/-/raw/{424e78130db2af6c1ceb55b442d7914b1109ff2b,v89}/archiso/mkarchiso
- archiso MRs !449, !462, !464, !445: https://gitlab.archlinux.org/archlinux/archiso/-/merge_requests/
- ALARM #2215 + comments + files: `gh api repos/archlinuxarm/PKGBUILDs/pulls/2215{,/files,/comments}`
- ALARM CONTRIBUTING: https://github.com/archlinuxarm/PKGBUILDs/blob/master/CONTRIBUTING.md
- ALARM `linux-aarch64` PKGBUILD (master): https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/linux-aarch64/PKGBUILD
- ALARM aarch64 core files db: http://mirror.archlinuxarm.org/aarch64/core/core.files.tar.gz (grub 2:2.14-1.1, archlinux-keyring 20260727-1)
- GRUB module enable flags: https://git.savannah.gnu.org/cgit/grub.git/plain/grub-core/Makefile.core.def
- mkinitcpio libalpm script: https://raw.githubusercontent.com/archlinux/mkinitcpio/master/libalpm/scripts/mkinitcpio
- limine-entry-tool 1.37.1 hooks: https://gitlab.com/Zesko/limine-entry-tool (`install/arch-linux/limine-mkinitcpio-hook/...`)
- Docker Hub: https://hub.docker.com/v2/repositories/{archlinuxarm/archlinuxarm,menci/archlinuxarm,archlinux/archlinux}; https://github.com/Menci/docker-archlinuxarm
- Arch `archiso` package: https://archlinux.org/packages/extra/any/archiso/
