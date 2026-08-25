# What upstream (omacom-io) would accept for the pkgbase gap and the ARM kernel

Research for [JimmayVV/omarchy-iso#16](https://github.com/JimmayVV/omarchy-iso/issues/16)
(map: [#1](https://github.com/JimmayVV/omarchy-iso/issues/1)). Read on 2026-08-24. Feeds
[#11](https://github.com/JimmayVV/omarchy-iso/issues/11).

## Question

What would omacom-io merge for the ALARM *pkgbase gap* (`linux-aarch64` ships no
`usr/lib/modules/<ver>/{pkgbase,vmlinuz}`, so mkinitcpio's and Limine's pacman hooks never fire
on an installed system) — (i) our own policy-compliant ALARM PR plus a self-retiring shim,
(ii) an omarchy-owned distinct-name kernel following ALARM's PKGBUILD through omarchy-pkgs, or
(iii) shim only — and which conventions must the whole Snapdragon layer follow to be mergeable?

## Answer in one paragraph

**Rank: (i) ALARM PR + self-retiring shim, then (ii) omarchy-owned kernel, then (iii) shim only.**
Upstream intent is not in doubt — DHH wrote `plans/aarch64-support.md` himself (2026-04-30,
direct push), naming Arch Linux ARM as the base and "Snapdragon X laptops" as a target, and said in
2025 "We will make arm first-class", "Will get an arm64 mirror and package repo setup too", and
"We need to add a dedicated mirror added for https://archlinuxarm.org/". What is in doubt is
*attention*: no maintainer has commented on, reviewed, labeled or reacted to any 2026 ARM thread
(omarchy-iso #121, basecamp/omarchy #8039, omarchy-pkgs #171/#195/#197/#199/#9, discussions
#7739/#7956/#7960), and every large ARM PR so far has died of size (#876: 9 DHH reviews then
superseded; #1897: 110 files, closed unreviewed at Quattro; pkgs #9: 83 files, 0 comments in ten
months) while small, hardware-scoped PRs from outsiders merge in minutes with no review (#116
55 min, #138 13 min). The kernel question has two direct precedents, both merged by DHH:
`linux-t2` (foreign unsigned repo, distinct pkgbase, selected by a hardware probe) and `linux-ptl`
(omarchy-owned Arch-PKGBUILD-verbatim-plus-patches, vendor-maintained). The decisive behaviour is
what DHH does with the patches afterwards: he deletes them the moment upstream has them ("Wifi fix
has been upstreamed already", "Patch now included upstream", "Remove packages Arch has since
absorbed"). A shim that says in its own header "no-op once `usr/lib/modules/*/pkgbase` exists;
delete after archlinuxarm/PKGBUILDs#2215 or successor merges", paired with an ALARM PR that
actually meets ALARM's CONTRIBUTING rules, is the smallest object matching that habit and needs no
aarch64 build/host infrastructure — which upstream has written (omarchy-pkgs PR #7, Ryan Hughes,
Oct 2025) but never run (`pkgs.omarchy.org/*/aarch64/` 404, no maintainer touch on the aarch64
path since Nov 2025). An omarchy-owned `linux-aarch64` rebuild is the `linux-ptl` shape and would
be accepted if the shim proves insufficient, but it replaces ALARM's kernel for every aarch64 user
to add two `install` lines, on a builder nobody upstream operates. Shim-only merges on day one but
makes the gap permanent, which is the one thing this team never does. The conventions list (§6)
is lifted from merged commits and from DHH's own review comments on the first aarch64 PR.

---

## 1. PR #121 and every ARM thread in omacom-io / basecamp — who has said what

Scope: `omacom-io` has 33 repos; the main Omarchy repo is **`basecamp/omarchy`**
(`omacom-io/omarchy` is 404). Searched issues + PRs (open and closed) in all of them plus
basecamp/omarchy Discussions for: ARM, aarch64, arm64, Snapdragon, X1E, Apple Silicon, Asahi,
Arch Linux ARM, ALARM, Arch Linux Ports, Qualcomm, Raspberry Pi, M1–M4, Parallels, UTM. 206 unique
threads; the relevant ones are below. Maintainers, by merge tally: **dhh** (omarchy-iso 32/38,
omarchy-pkgs 64/124, basecamp/omarchy 290 of the newest 300) and **ryanrhughes** (4, 58, 10);
`Torxed` merged 2 in omarchy-iso; `omarchybot`/`Omabot` is a maintainer-run bot. No public org
members; no CONTRIBUTING.md, PR template or issue template in omarchy-iso or omarchy-pkgs.

### 1a. PR omacom-io/omarchy-iso#121 (the baseline ISO)

| Item | Value | Source |
| --- | --- | --- |
| Author / state | `oceanapplications` ("Sean"; account since 2012, no bio, **zero prior commits or merged PRs** in omacom-io/basecamp); draft, toggled draft↔ready four times, last to draft 15:35Z; base `quattro`, +574/−33, 11 files, 7 commits 12:33–15:52Z on 2026-08-24 | `gh pr view 121` |
| Labels / assignees / review requests | none | same |
| Reviews | 4, all `greptile-apps[bot]` (P1 findings on `build-iso.sh` ×3 and `customize_airootfs.sh`: "Unconditional ARM inputs break x86 builds", "ARM boot profile remains x86-only", "Loopback boot keeps x86 kernel", "Initramfs failure produces unbootable ISO" — each fixed by a follow-up commit; final "Confidence Score: 5/5") | `gh api repos/omacom-io/omarchy-iso/pulls/121/reviews` |
| Human comments / reactions | **None. No maintainer has commented, reviewed, labeled, reacted to or touched it.** One 👍 from the bot | `gh api .../issues/121/{comments,reactions}` |
| Maintainer mentions of kernel / ALARM vs Ports / scope | none on this PR | — |
| Author's own framing | ALARM as base ("Arch Linux ARM has none [archiso]"), stock `linux-aarch64`, pkgbase gap named and delegated to ALARM #2215: "Until that lands an aarch64 install completes and then writes no boot entries." Tested "natively rather than under QEMU" on ALARM 7.2.0-1 — in a Parallels VM on Apple Silicon per the companion PR #8039, **not on Snapdragon hardware** | PR #121 body; basecamp/omarchy#8039 body |
| Same-day companion threads by the author | basecamp/omarchy#8039 (three `uname -m` guards; copilot-bot review only), omarchy-pkgs #195 (nine `arch=()` additions, greptile 5/5), #197 (1password aarch64, draft), issue #199 ("Publish an aarch64 tree at pkgs.omarchy.org"), archlinuxarm/PKGBUILDs#2215, Zesko/limine-entry-tool!63 — **all with zero maintainer response** | §3a, §7 |

### 1b. The plan is the maintainers' own

`plans/aarch64-support.md` was created by **dhh** in `2d8ed3d` "More plans" (2026-04-30, direct
push to `quattro`, no PR), edited by ryanrhughes `c50d0bc` (2026-05-25, reworded the guard
prerequisite the day he deleted `install/preflight/guard.sh` from omarchy) and by dhh `ed710a3`
(2026-07-27, preset section). Verbatim: "Target: a parallel **generic UEFI aarch64** ISO — boots
on Ampere servers, AWS Graviton VMs, Snapdragon X laptops, ARM dev kits. … Apple Silicon (Asahi)
and SBCs (U-Boot/rpi-firmware) are out of scope." / "The realistic source is **Arch Linux ARM**
… Decision required: target Arch Linux ARM as the aarch64 base distribution." / "`pkgs.omarchy.org/
{stable,edge}/aarch64/` must serve a real repo. Probed today, both return 404. omarchy-pkgs already
has multi-arch build support per its README, so this is a publish step, not a port." / "Don't fork
the profile directory — overlay arch-specific files at build time so the two architectures share
one source of truth." / verification: "One physical ARM64 UEFI box if available (Ampere dev kit,
Snapdragon X laptop, etc.) — the long pole."

### 1c. Maintainer statements on ARM, chronological (verbatim, all re-fetched from the API)

| Date | Who / where | Quote | Read |
| --- | --- | --- | --- |
| 2025-07-07 | dhh, [basecamp/omarchy#87](https://github.com/basecamp/omarchy/issues/87#issuecomment-3046101509) | "Hyprland is x86 only, so until that might change, Omarchy will not be targeting or compatible with arm." | The only "no"; reversed within six weeks |
| 2025-08-14 | dhh, #87 | "But those are emulating x86, no? Then sure, that'll work! Talking about running things natively." / "How are you running packages like chromium that don't have aarch64 builds?" | Concern is package availability |
| 2025-08-11 | dhh, PR #524 / commit `31ab6b49` | Added `[ "$(uname -m)" != "x86_64" ] && abort` with "Proceed anyway on your own accord and without assistance?" (guard deleted 2026-05-25 `75cb4f71`; Quattro has no arch guard anywhere) | — |
| 2025-08-22 | dhh, [PR #876 "Add aarch64 support"](https://github.com/basecamp/omarchy/pull/876#pullrequestreview-3144319080) review | "I'm shocked how little change we actually need to support things! Love it." | First constructive engagement |
| 2025-08-22/23 | dhh, #876 review comments | "Let's just drop this entire thing since it was just there to guard against arm installs. But we should test that it works on a Pi as well." / "Let's add this in its own preflight/arm.sh file. Guard should just be about rejecting installs." / "Put all this into the preflight/asahi.sh file" / "Think this install guide needs to be somewhere else. Not in the main repo." / "The fewer manual steps the better!" | **Conventions**: arch logic in its own file, no manual steps, no docs in the repo |
| 2025-08-24 | dhh, [discussion #452](https://github.com/basecamp/omarchy/discussions/452#discussioncomment-14202270) | "The warning is skippable. And I love the idea that we can get Omarchy on Apple hardware. We'll get the entire flow ironed out so it Just Works." | |
| 2025-08-27 | dhh, [discussion #155](https://github.com/basecamp/omarchy/discussions/155#discussioncomment-14233774) | "We will make arm first-class. Just have to nail down x86. I really want the arm install story to be totally seamless." | Intent |
| 2025-08-31 | dhh, #876 review comments | "I don't think we need to tailor this. It's fine to have rules for apps that aren't yet available on arm. We'll eventually get everything there and it'll be easier to maintain as just one set of rules." / "I'd rather add this as a specific patch to the file during aarch64 install. Don't want to maintain duplicate lists here." / "This seems like something that should just be in the aarch64 group, so we don't install this for everyone else." | **Conventions**: one list, patch-at-install, arch-specific package group |
| 2025-08-31 | dhh, [#803 "om-arm-archy ?"](https://github.com/basecamp/omarchy/issues/803#issuecomment-3239860509) | "Closing as pursued in #876" (state later NOT_PLANNED, 2025-11-03) | Tracked, not refused |
| 2025-09-06 | dhh, [discussion #452](https://github.com/basecamp/omarchy/discussions/452#discussioncomment-14325738) | "We will fix all of this. Arm64 will be priority. We should have Omarchy working on as many devices out of the box as possible. Will get an arm64 mirror and package repo setup too 👌." | Commitment to host |
| 2025-09-08 | dhh, [#876](https://github.com/basecamp/omarchy/pull/876#issuecomment-3266750243) | "I would love to get everything boiled down to a single script that does it all." / "We need to add a dedicated mirror added for https://archlinuxarm.org/ to deal with the aarch64 packages." | **ALARM named as the base by DHH** |
| 2025-10-11 | ryanrhughes, [#2330](https://github.com/basecamp/omarchy/issues/2330#issuecomment-3393724175) | "As mentioned already, Arch itself is really only x86_64. If / when we have aarch64 variants, we'll deal with that." | |
| 2025-10-27 | ryanrhughes, [#876](https://github.com/basecamp/omarchy/pull/876#issuecomment-3452861065) closing | "Closing in favor of #1897. We should continue to clean that up and whittle it down to only the required elements but it's the closest to 1-1 addition of aarch64 support at the moment." | "whittle it down" |
| 2025-10-30 | ryanrhughes | Authors and self-merges omarchy-pkgs#7 "Add aarch64 build support" (ALARM rootfs + keyring) | Team builds the capability |
| 2025-11-20 | dhh, [PR #3449](https://github.com/basecamp/omarchy/pull/3449#issuecomment-3557838251) closing | "We don't have a fully verified setup for arm yet. So don't want to remove the guard until we do. You can always continue anyway." | "verified" is the bar |
| 2026-04-30 | dhh | writes `plans/aarch64-support.md` (§1b) | |
| 2026-07-18 | dhh, [PR #1897](https://github.com/basecamp/omarchy/pull/1897#issuecomment-5012441718) closing (jondkinney, +6653/−190, 110 files, 95 comments, 109 reactions; dhh never reviewed it in-line) | "Closing since this targets the pre-Quattro architecture and can no longer be applied to the current codebase. If the underlying idea is still relevant after Quattro, it can be proposed again against the new implementation. Thanks for the contribution!" | Door open for a Quattro-era PR; big PRs die |
| 2026-08-20 | omarchybot (maintainer bot), omarchy-pkgs README `1b14682` / PR #180 | "aarch64 is not covered. Those builds resolve Qt from Arch Linux ARM, which can lag Arch … if ARM publishing starts, `rebuilt_against` has to become per-architecture before this can be trusted there." / "x86_64 only, deliberately." | Maintainer tooling still assumes ALARM as the aarch64 base |
| 2026-08-22 → 24 | (nobody) | Discussions #7739 "Snapdragon X (x1p42100) aarch64 laptop — is there any path to Omarchy 4" (2 user replies), #7956 (Quattro in a native aarch64 UTM VM), #7960 "FR: Support aarch64" (0 comments); PRs #121, #8039, #171, #195, #197; issue #199 | **No maintainer reply on any 2026 ARM thread** |

### 1d. Outcomes of every ARM PR to date

| PR | Size | Outcome |
| --- | --- | --- |
| basecamp/omarchy#367 malik-na "nvidia drivers and asdcontrol disabled on aarch64, asahi bootloader support" (2025-07-26) | small | closed by author same day, 0 comments |
| basecamp/omarchy#628 daltonbr "Add preflight check for OS and architecture" | small | closed by dhh; arch check cherry-picked with credit ("I grabbed just the arch check from here and gave you credit") |
| basecamp/omarchy#876 nilszeilon "Add aarch64 support" | medium | 9 dhh reviews, 13 review threads, 93 reactions; closed by ryanrhughes in favour of #1897 |
| basecamp/omarchy#1897 jondkinney "Add aarch64 support for Omarchy 3.x" | 110 files | closed by dhh at Quattro, never reviewed by a maintainer |
| basecamp/omarchy#3449 "Allow experimental arm64/aarch64 installs in preflight guard" | 1 line | closed by dhh: not until "a fully verified setup" |
| basecamp/omarchy#5901 axelfontaine "Enable Docker multi-arch builds by default" | small | **merged by dhh 2026-05-19** (docker `linux/arm64` images, not native ARM) |
| omarchy-pkgs#7 ryanrhughes "Add aarch64 build support" | 11 files | **merged** (self) 2025-10-30 |
| omarchy-pkgs#9 jondkinney "Add arm support" | 83 files, +2748 | open since 2025-11-03, `mergeable_state: dirty`, 0 comments in ten months |
| omarchy-pkgs#171 scottjones "Build aarch64 packages on native ARM64 runners" | 6 files | open 2026-08-19, 0 comments |
| omarchy-pkgs#195 / #197, basecamp/omarchy#8039, omarchy-iso#121 (oceanapplications) | 3–15 files each | open 2026-08-24, bot reviews only |
| Apple-Silicon quirk PRs #7488, #7553, #7577, #7948, #7951 (Aug 2026) | small | open, no maintainer comment (omarchybot on #7577: "This is waiting on the maintainer") |

The only ARM-flavoured PRs ever merged are the team's own (#7) and a docker-image one (#5901).
Every attempt at "add aarch64 support" in one PR has been closed or is rotting. The pattern
matches omarchy-iso's general review style: dhh often re-applies small external patches himself
with `Co-Authored-By` (#59, #61, #67, #87/#89, #92) and closes large stale PRs with courteous
explanations once the code has moved under them (#80, #72, #70, #60, #43, #32, #102).

How omarchy-iso handles submodule changes (dhh, PR #30, 2025-08-30): "We can't just change
directly inside the submodule, because that's being pulled from upstream. If this is a change
we're making, we have to make it as a patch." — this settles the map's archiso-patch question
(#7's carried `builder/patches/archiso-grub-modules-arm64.patch` is the accepted shape).


## 2. The `linux-t2` and `linux-ptl` precedents — hardware-specific kernels upstream already ships

### 2a. `linux-t2`: a foreign-repo kernel under a distinct name

| Item | Evidence | Source |
| --- | --- | --- |
| Who introduced it | Ryan Hughes (`ryan@heyoodle.com`, omacom-io team) — `4639b85` "Add t2 mirror" (2025-09-12) and `234b54c` "Change T2 upstream to the github mirror for now" (2025-09-14) in omarchy-iso; `772a7537` "Add T2 MacBook support (#1657)" in omarchy (2025-09-14), co-authored by DHH | local `git log -S'linux-t2'`; https://github.com/basecamp/omarchy/pull/1657 |
| How it was reviewed | PR #1657: opened 04:54Z, **merged by `dhh` 17:49Z the same day, zero reviews**, only two later drive-by user comments | `gh api repos/basecamp/omarchy/pulls/1657` |
| Where the repo lives | `[arch-mact2]` appended to **all three** ISO pacman configs (`configs/pacman-online-{stable,rc,edge}.conf`) with `SigLevel = Never` and two `Server=` lines; DHH himself added the fallback mirror (`a72a109`, 2026-07-22) | local `configs/pacman-online-stable.conf` lines 32–35 |
| Installed-system side | `install/hardware/pacman.sh` appends the same `[arch-mact2]` block (`SigLevel = Never`) to the target's `/etc/pacman.conf`, gated on `lspci -nn \| grep "106b:180[12]"`; comment: "Hardware-specific pacman repository extensions that must survive the final pacman.conf restore" | https://github.com/basecamp/omarchy/blob/master/install/hardware/pacman.sh |
| Kernel selection | `configurator` `detect_kernel()`: `lspci` T2 probe → `linux-t2`, else `linux`; comment "T2 Macs need their own kernel for keyboard/wifi drivers" | omarchy-iso `configs/airootfs/root/configurator` lines 413–420 |
| Package lists | `linux-t2`, `linux-t2-headers`, `apple-bcm-firmware`, `apple-t2-audio-config`, `t2fanrd` under "# T2 MacBook support packages" in `install/omarchy-other.packages` (header: "Utilized by ISO builder to ensure package availability in the ISO") | https://github.com/basecamp/omarchy/blob/master/install/omarchy-other.packages |
| Quirk script | `install/hardware/apple/fix-t2.sh`: `omarchy-pkg-add linux-t2 ...`, writes `/etc/mkinitcpio.conf.d/apple-t2.conf` (`MODULES+=`), `/etc/limine-entry-tool.d/t2-mac.conf` (`KERNEL_CMDLINE[default]+=`), `/etc/t2fand.conf`; run from `install/hardware/all.sh` | https://github.com/basecamp/omarchy/blob/master/install/hardware/apple/fix-t2.sh |
| Live ISO kernel | The ISO boots `linux-t2` on *every* machine; `configs/airootfs/etc/mkinitcpio.d/linux-t2.preset` ("The filename is the pkgbase, and that is load-bearing"); DHH's `ed710a3` / `0631c05` (2026-07-27) fixed a 10-month bug where the ISO silently booted stock Arch | omarchy-iso `builder/build-iso.sh` lines 121–136 |
| Upgrade handling | `migrations/1785273276.sh` ("linux-t2 7.1.4 replaced the apple-bce driver with t2bce") and `migrations/1785944594.sh` — omarchy tracks the foreign kernel's breaking changes with migrations | https://github.com/basecamp/omarchy/tree/master/migrations |

What this proves: upstream will ship a kernel from a **third-party unsigned repo** under a distinct
pkgbase, add the repo to both the ISO and the installed system, select it by a hardware probe in
the configurator, and carry its churn in `migrations/`. The kernel package itself lives outside
omacom-io entirely.

### 2b. `linux-ptl`: an omarchy-owned kernel carrying not-yet-upstream patches

| Item | Evidence | Source |
| --- | --- | --- |
| Origin | `linux-ptl-audio` → renamed `linux-ptl` by Spencer Bull (Dell) `929c8d0` 2026-03-24; PR #77 by Gaggery Tsai (Intel) merged by `dhh` 2026-04-21. PKGBUILD header: "Maintainer: Gaggory Tsai <…@intel.com> Spencer Bull <…@Dell.com> / Based on Arch Linux linux package by Jan Alexander Steffens (heftig)" | https://github.com/omacom-io/omarchy-pkgs/pull/77 ; `pkgbuilds/linux-ptl/PKGBUILD` |
| Shape | Arch's `linux` PKGBUILD + `config.x86_64` verbatim, plus numbered `00NN-*.patch` files; `pkgdesc='Linux for Panther Lake with Panel Replay power and OLED VRR fixes'`; `.omarchy/package.json` = `{"source": "local", "skip_build": true}` (built explicitly, not on the unscoped schedule) | `pkgbuilds/linux-ptl/PKGBUILD` lines 1–10, 138–141 |
| Ships `pkgbase`/`vmlinuz` | `install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"` and `echo "$pkgbase" \| install -Dm644 /dev/stdin "$modulesdir/pkgbase"` — the exact two lines ALARM lacks | `pkgbuilds/linux-ptl/PKGBUILD` lines 138, 141 |
| **DHH retires patches as upstream absorbs them** | `7514a91` 2026-04-22 "Wifi fix has been upstreamed already" (−201 lines); `0f290b9` 2026-04-27 "Patch now included upstream" (−57 lines); `d5aa4b7b` (omarchy, 2026-04-30) "Only XPS now needs the custom ptl kernel" — scope shrank from "all Intel PTL" (`4d6221c8` 2026-03-24) to XPS only as mainline caught up | local `git log` in omarchy-pkgs / omarchy |
| Review pattern for external kernel PRs | #99 (spencerbull → dhh, 4 days, 0 reviews), #116 (55 min, 0 reviews), #117 (35 min), #131 (7 h), #138 (13 min), #77 (11 days, 2 contributor comments, 0 maintainer comments). Merged on the strength of the PR body's "Validation"/"Tested on XPS 14 & 16" sections | `gh pr view` on each |
| Installed-system side | `install/hardware/intel/ptl-kernel.sh`: gated `omarchy-hw-match "XPS" && omarchy-hw-intel-ptl`; `omarchy-pkg-add linux-ptl linux-ptl-headers`; `pacman -Rdd linux`; drop-in `/etc/limine-entry-tool.d/zz-dell-xps-panther-lake.conf` with `BOOT_ORDER="linux-ptl*, *fallback, Snapshots"`. Comment: "The linux-ptl kernel includes audio driver patches not yet in mainline." | https://github.com/basecamp/omarchy/blob/master/install/hardware/intel/ptl-kernel.sh |
| Third variant pending | PR #124 (meirdick, 2026-08-07, open, draft→ready cycles, 0 maintainer comments) adds three more patches to `linux-ptl` plus `hp-elitebook-x-g2i-{audio,camera}` packages; "Upstream status. Patches 0030 and 0031 are mine to send to alsa-devel … each one accepted later removes a layer from this packaging." Open kernel PRs #90, #97, #136, #150, #163 follow the same shape | https://github.com/omacom-io/omarchy-pkgs/pull/124 |

What this proves: upstream *does* own hardware kernels in omarchy-pkgs, they are contributed by
outsiders (vendors), merged fast on a testing statement, and — the key behaviour — **every local
patch is treated as a temporary carry that DHH removes the moment it is upstream.** Contributors
are expected to say where the patch is going upstream.

### 2c. How kernel → initramfs → Limine is wired (the chain the pkgbase gap breaks)

| Link | Mechanism | Source |
| --- | --- | --- |
| Kernel → initramfs | Arch's `mkinitcpio` alpm hook `90-mkinitcpio-install.hook` targets `usr/lib/modules/*/vmlinuz`; its script reads `usr/lib/modules/*/pkgbase` to name the preset | prior research (#7), `linux-t2.preset` comment in omarchy-iso |
| initramfs → Limine | `limine-mkinitcpio-hook` (omarchy-pkgs, wraps Zesko's `limine-entry-tool` 1.37.1): `arch=('x86_64' 'aarch64')`, `source_aarch64=` GraalVM arm64 — **already arch-gated for aarch64 by upstream**; pacman hooks target `usr/lib/modules/*/pkgbase` | `pkgbuilds/limine-mkinitcpio-hook/PKGBUILD` |
| Limine on non-x86 | `limine-entry-tool` exits 0 on non-x86_64 ("The system is not x86_64.") — Zesko MR !63 (Sean Baker = oceanapplications, 2026-08-24, open) removes the gate; PR #121's orchestrator hardcodes `limine_x64.efi` in nine places and the PR fixes them | https://gitlab.com/Zesko/limine-entry-tool/-/merge_requests/63 ; PR #121 body |
| Per-hardware kernel knobs | Drop-ins, never edits: `/etc/mkinitcpio.conf.d/<hw>.conf`, `/etc/limine-entry-tool.d/<hw>.conf` (named `zz-` to sort after `omarchy-defaults.conf`), `/etc/modules-load.d/<hw>.conf`, `/etc/modprobe.d/` | `fix-t2.sh`, `ptl-kernel.sh`, `migrations/1784917531.sh` |
| `linux-snapper-sync` | `limine-snapper-sync` also `arch=('x86_64' 'aarch64')` | `pkgbuilds/limine-snapper-sync/PKGBUILD` |

## 3. omarchy-pkgs conventions and the state of aarch64 upstream

### 3a. Does upstream build or host aarch64 today? No — but the team built the capability

| Probe | Result | Source |
| --- | --- | --- |
| `https://pkgs.omarchy.org/stable/aarch64/omarchy.db` | **404** | curl 2026-08-24 |
| `https://pkgs.omarchy.org/edge/aarch64/omarchy.db` | **404** | curl 2026-08-24 |
| `https://pkgs.omarchy.org/stable/x86_64/omarchy.db` | 200 (38 793 B) | curl 2026-08-24 |
| Who wrote multi-arch | **Ryan Hughes (team)**: `f6cc3f3` "Initial working concept for aarch64" 2025-10-29, `78c1ef2` "Unified aarch64 / amd64 image", PR #7 "Add aarch64 build support" opened and self-merged 2025-10-30 (files: `build/Dockerfile.aarch64`, `build/bootstrap/Dockerfile.alarm-base`, `build/bootstrap/alarm-signing-key.asc`, `create-alarm-base.sh`); `4d088d8` "Fix qemu issue" 2025-11-04; `aca2584` "Update sync and release to use mirror / arch" 2025-11-21 | https://github.com/omacom-io/omarchy-pkgs/pull/7 ; local `git log -S'aarch64'` |
| Base distro the team chose for aarch64 | **Arch Linux ARM.** `build/Dockerfile` line 3: "Supports: x86_64 (Arch Linux) and aarch64 (Arch Linux ARM)"; the arm64 branch pulls ALARM's `pacman-mirrorlist`, ALARM's keyring, and adds `[alarm]` + `[aur]` repos | `build/Dockerfile` lines 1–75 |
| README | "**Multi-Architecture**: Supports both x86_64 and aarch64 (ARM64)"; "aarch64 Builds (Optional) — To build ARM64 packages on x86_64, enable QEMU emulation"; `bin/repo release --arch aarch64` | `README.md` |
| Arch gating | `build/build.sh` `should_build_for_arch()`: sources the PKGBUILD, builds if `arch=('any')` or `$ARCH` ∈ `arch=()`, else prints "not built for $ARCH" and skips. `bin/{build,sign,promote-build,update-repo,deploy,migrate-edge-to-stable,list-packages}` all take `--arch` | `build/build.sh` lines 154–176 |
| The team once shipped an aarch64-only patched package | `c6eacf4` Ryan Hughes 2025-11-04 "Add patched signal-desktop for aarch64" (`patches/aarch64.patch`), removed `810efcc` 2026-05-07 "Remove signal - on extra" | local `git log` |
| Maintainer activity on the aarch64 path since Nov 2025 | **None** beyond the generic refactor (`2ffe4f8` 2026-05-08) and Scott Jones' `95ca4cd` "Mark tobi-try arch=any" | local `git log -S'aarch64' -- bin build helpers` |
| Contributor pressure, all in the last week | #171 scottjones "Build aarch64 packages on native ARM64 runners" (2026-08-19, `ubuntu-24.04-arm` workflow, deliberately does not publish; motivated by Apple Silicon `omarchy-mac`); #195 oceanapplications "Add aarch64 to arch=() for packages that build natively on ARM64" (2026-08-24, nine packages, patches under `.omarchy/patches/add-aarch64-arch.patch` so `sync-aur` keeps them); #197 "1password: build for aarch64" (draft, `.omarchy/post-sync.sh`); issue #199 "Publish an aarch64 tree at pkgs.omarchy.org" (2026-08-24). **Zero maintainer replies on any of them** as of 2026-08-24 20:00Z; only `greptile-apps` bot reviews | https://github.com/omacom-io/omarchy-pkgs/pull/171 , /pull/195 , /pull/197 , /issues/199 |

### 3b. Package-shape conventions (all from README or merged code)

| Convention | Rule | Source |
| --- | --- | --- |
| Metadata | Every package has `.omarchy/package.json`; `"source": "aur"` (synced) or `"local"` (Omarchy owns the PKGBUILD) | README "PKGBUILDs", "Fields" |
| Vendor feed | `"source": "local"` + `.omarchy/upstream.sh` printing `{"pkgver": …, "sha256sums": {"x86_64": [...], "aarch64": [...]}}`; "Hooks should read checksums from whatever manifest the vendor publishes rather than downloading the artifacts". Added by DHH `01a566f` 2026-08-15 | README "Sync Upstream Releases"; `bin/sync-upstream` |
| Surviving AUR sync | Modifications to AUR packages go in `.omarchy/patches/*.patch` (static) or `.omarchy/post-sync.sh` (dynamic); a bare PKGBUILD edit is reverted on next sync | README "Local Customizations for AUR Packages"; PR #195/#197 bodies |
| Opting out of scheduled builds | `"skip_build": true` (used by `linux-ptl`) — kernels are built explicitly with `bin/repo release --package` | README "Fields"; `pkgbuilds/linux-ptl/.omarchy/package.json` |
| Hook-only packages | **No precedent.** The only `.hook` files in `pkgbuilds/` are `quickshell-git/quickshell-check.hook` and hooks inside `omarchy`/`omarchy-dev` (grep `libalpm/hooks`). The closest shapes are `dell-xps-touchpad-haptics` (`source: local`, `arch=('x86_64')`, config presets only) and `hp-elitebook-x-g2i-audio` in PR #124 (UCM file + systemd unit + `.install`) | `grep -rl 'libalpm/hooks' pkgbuilds` |
| Retiring packages | `#177` (omarchybot → dhh, 2026-08-20) "Remove packages Arch has since absorbed" — packages are deleted when the official repos carry them; `#170` "Package the herdr 0.8.2 release instead of the fork" once "all patches are upstream" (`aaa7610`) | https://github.com/omacom-io/omarchy-pkgs/pull/177 |
| Review bots | `greptile-apps` reviews omarchy-pkgs PRs; `copilot-pull-request-reviewer` reviews basecamp/omarchy PRs. Neither is a maintainer signal | PR #195, #197, basecamp/omarchy#8039 |

### 3c. Arch gating in the ISO (PR #121's contribution to the convention)

`OMARCHY_ARCH_DROP` in the PR's `builder/build-iso.sh` is a single categorised list applied to all
four package lists ("1. x86/x86_64 platform hardware. Meaningless on ARM, not a gap" — includes
`linux-t2`, `linux-ptl`, all T2/Intel/NVIDIA/ASUS/Dell/Tuxedo packages; "2. x86-only
virtualisation guest tooling"; "3. Software with no aarch64 build … real gaps"; "4. Build artefacts /
not carried by ALARM"). `configs/profiledef.sh` switches `arch`, `bootmodes` and the squashfs
compressor on `uname -m`; the aarch64-only files live in `configs/aarch64/` and are staged only on
that architecture; `detect_kernel()` returns `linux-aarch64` on aarch64 before the T2 probe. The
PR's stated invariant — "on x86_64 every selector resolves to the value it has today, and the
files x86 reads … are byte-identical to `quattro`" — is the bar any Snapdragon commit on top of it
must also clear.

## 4. Public statements by DHH / the Omarchy team on ARM (outside GitHub threads)

Manual and site (basecamp/omarchy `manual/*.md`, mirrored at https://omarchy.org/manual/; legacy
copy at learn.omacom.io/2/the-omarchy-manual):

| Where | Verbatim | Source |
| --- | --- | --- |
| `manual/44-mac-support.md` | "Omarchy has built-in support for **Intel Macs**." / "Please note that installing on an M-series Mac is not directly supported at this time. You can find out more about the state of this in #omarchy-on-other in our Discord." / "On these models, the installer automatically sets up the patched `linux-t2` kernel, the T2 audio configuration, Apple's Broadcom Wi-Fi/Bluetooth firmware, and fan control via `t2fanrd`." | https://github.com/basecamp/omarchy/blob/quattro/manual/44-mac-support.md |
| `manual/49-omarchy-on.md` (dhh, `55434792` 2026-08-13) | "### Apple M1/M2 chips — [Asahi Alarm] is a version of Arch for Apple M1/M2 computers built on top of Asahi Linux. You can get Omarchy running on top of that with some effort. See [the user-driven guide]" (→ codeberg.org/malik-na/omarchy-mac) / "### Apple Virtual Machine — You can also install Omarchy inside a Parallels VM. Quite the cumbersome process" / "### Something else! — … join the #omarchy-on-other channel" | https://github.com/basecamp/omarchy/blob/quattro/manual/49-omarchy-on.md |
| `manual/01`, `02`, FAQ, front page | No architecture requirement stated anywhere; "Omarchy is an omakase Linux distribution based on Arch" | omarchy.org, manual |
| Issue templates | `blank_issues_enabled: false`; "GitHub issues should be used for verified bugs only"; suggestions → Discussions; "Omarchy is an open source gift, not a product you bought from a vendor" (dhh `54795a2f` 2025-11-03, `bee90aa1` 2025-09-06) | `.github/ISSUE_TEMPLATE/{config,bug}.yml` |
| Release notes v1.1.1 → v4.0.0 (62 releases) | **No release mentions arm/aarch64/asahi/snapdragon.** v1.13.0: "Add guard against installing Omarchy on anything but a fresh vanilla Arch on x86_64 (but option to override)"; v3.0.0: "install Omarchy on most pre-M MacBooks … Add support for T2 macs with custom kernel and drivers by @ryanrhughes + @nunix"; v3.5.0: "Omarchy has worked with Intel and Dell to provide complete support and optimization out of the box." | `gh api repos/basecamp/omarchy/releases` |

DHH's own posts (X re-fetched via the fxtwitter API on 2026-08-24; blog fetched directly):

| Date | Where | Verbatim | Implication |
| --- | --- | --- | --- |
| 2024-06-10 | [x.com/dhh/status/1800125958714020110](https://x.com/dhh/status/1800125958714020110) | "This is freaking awesome. Snapdragon X Elite running Linux on a Tuxedo laptop before the end of 2024? THE PROPHESY DRAWS CLOSER!" | Pre-Omarchy; the only Snapdragon post found |
| 2025-04-17 | [world.hey.com/dhh/the-new-framework-13-hx370-68675e0e](https://world.hey.com/dhh/the-new-framework-13-hx370-68675e0e) | "…not as good as a Qualcomm machine or an Apple M-chip machine." | Only Qualcomm mention on the blog |
| 2025-07-21 | [x.com/dhh/status/1947139386144907621](https://x.com/dhh/status/1947139386144907621) | "Asahi doesn't run on M4 or M3. Only M1 and M2. Folks have gotten Omarchy running, but there's a laundry list of caveats. If you're serious about Linux, just get a @FrameworkPuter 13." | |
| 2025-08-09 | [world.hey.com/dhh/all-in-on-omarchy-at-37signals-68162450](https://world.hey.com/dhh/all-in-on-omarchy-at-37signals-68162450) | "giving up on MacBooks and choosing Framework laptops as the new standard-issue equipment" | 37signals' fleet is x86 |
| 2025-08-22 | [x.com/dhh/status/1958766420436590867](https://x.com/dhh/status/1958766420436590867) | "Just because Apple gives up on its hardware doesn't mean you have to! Will work to make future Omarchy ISOs have everything in the box to save MacBooks left behind by Apple from obsolence." | Intel-Mac framing |
| 2025-09-13 | [x.com/dhh/status/1966940450394083619](https://x.com/dhh/status/1966940450394083619) | "You can't use the Omarchy ISO for M1. You first need to install Asahi Alarm, then do a manual install." | |
| 2026-04-06 | [world.hey.com/dhh/panther-lake-is-the-real-deal-4bd731f1](https://world.hey.com/dhh/panther-lake-is-the-real-deal-4bd731f1) | "If you've been waiting on the sidelines for a laptop that can run Omarchy and still get amazing battery life, now is your magic moment. Give the new Dell XPS series, or any of the other laptops shipping with Panther Lake, a try." | ARM's battery argument answered with x86; the `linux-ptl` partnership |
| 2026-08-22 | [x.com/dhh/status/2091216032450908668](https://x.com/dhh/status/2091216032450908668) | "Going to double down on the MacBook mission with Omarchy. We almost have perfect coverage for the vintage Intel era going from 2009-2020. There's a straight shot to get the M1 and M2 machines going too, even if it's a lot more work. But we'll do the work. We'll fix everything." | **Most recent ARM commitment — Apple Silicon, two days before #121** |

Nothing found: no blog post or tweet pairing Omarchy with Snapdragon/Qualcomm; no "Contributing"
chapter; no interview transcript with a primary URL. The product direction in DHH's own words is
x86 (Framework, then Intel/Dell Panther Lake) with ARM as a side quest whose emotional target is
Apple Silicon via Asahi; the *written plan* in omarchy-iso, by contrast, puts Apple Silicon out of
scope and names Snapdragon X. Both are DHH's. A Snapdragon PR therefore lands on the plan's side
of that tension and should say so in its body.


## 5. Workaround packages vs upstream-distro fixes — what omacom-io actually does

| Case | What they did | Retired? | Source |
| --- | --- | --- | --- |
| `linux-ptl` patches (audio SDCA, iwlwifi, i915 panel replay) | Carried in an omarchy-owned kernel | Yes — DHH deleted each as it landed upstream (`7514a91`, `0f290b9`); scope narrowed to XPS (`d5aa4b7b`) | omarchy-pkgs / omarchy git log |
| `herdr` | Forked ("Maintain a herdr fork until we can get upstream feature changes", `0c71613` 2026-08-08) | Yes — 11 days later "Update herdr to 0.8.0.r6 now that all patches are upstream" (`aaa7610`), then tracks upstream (`e2e916f`) | omarchy-pkgs git log |
| `v4l2-relayd` | Carries `reset-output-on-idle.patch` over the AUR package, `sync: false`, documented in `.omarchy/README.md` | No (still carried) | `pkgbuilds/v4l2-relayd/.omarchy/README.md` |
| initramfs async race (kernel 7.1 vs Plymouth) | `migrations/1784917531.sh`: "Force synchronous unpacking until the race is fixed upstream" — a cmdline drop-in, not a package | Pending upstream | https://github.com/basecamp/omarchy/blob/master/migrations/1784917531.sh |
| ASUS Z13 touchpad | udev rule in `install/hardware/asus/fix-z13-touchpad.sh` explaining why upstream libinput's quirk is insufficient | No | https://github.com/basecamp/omarchy/blob/master/install/hardware/asus/fix-z13-touchpad.sh |
| T2 kernel module rename (`apple-bce` → `t2bce`) | `migrations/1785273276.sh` repairs the boot image on upgrade | n/a | migrations |
| `intel-lpmd`, `pinta`, `umu-launcher` | Deleted once Arch's official repos carried them (#177) | Yes | https://github.com/omacom-io/omarchy-pkgs/pull/177 |
| Contributor kernel patches (#124) | Contributor states "Patches 0030 and 0031 are mine to send to alsa-devel and are not filed yet … each one accepted later removes a layer from this packaging" — the expected framing | Planned | https://github.com/omacom-io/omarchy-pkgs/pull/124 |

Pattern: omacom-io **ships the workaround immediately and retires it when upstream lands**, with
the retirement done by DHH himself. They do not block on the upstream distro, and they do not
keep workarounds a day longer than needed. Nothing in the history shows them refusing a
workaround because the fix "belongs upstream"; nothing shows them keeping one after upstream fixed
it. There is no example of omacom-io filing the upstream fix themselves — the contributor is
expected to do that (#124's author, DHH's herdr fork notwithstanding).

## 6. Recommendation

### Ranking

**(i) Fix ALARM + self-retiring shim — first.** Evidence:

1. It is the exact `linux-ptl`/`herdr` shape: a carried fix with a named upstream destination that
   DHH deletes once upstream has it (§5). A shim whose hook comment says "no-op once
   `usr/lib/modules/*/pkgbase` exists; delete after archlinuxarm/PKGBUILDs#2215 or successor
   merges" is the smallest thing that matches.
2. It needs no aarch64 build/host infrastructure that upstream does not have (§3a: 404 today,
   no maintainer activity on the aarch64 path since Nov 2025, four contributor PRs/issues
   unanswered this week). A hook-only `arch=('any')` or `arch=('aarch64')` package is one
   `bin/repo release --package` away; a kernel is not.
3. ALARM #2215 is stalled only on *form* — graysky2's sole reply is a link to CONTRIBUTING.md,
   whose rules the draft breaks (three packages in one PR; no pkgrel bump per package; no
   clean-chroot build statement on all arches). A one-package PR (`core/linux-aarch64` only,
   `pkgrel` 2 → 2.1 per "Upstream x86 Arch Linux packages" rules, built in a clean chroot on
   aarch64, "why" = Arch's `mkinitcpio` and every bootloader hook key on the file) is within the
   map's allowed contact (ALARM is not omacom-io).
4. It keeps PR #121's design intact — stock `linux-aarch64`, `detect_kernel()` → `linux-aarch64`,
   `validate_boot()` keyed on that pkgbase — and #121's own `customize_airootfs.sh` already
   documents the gap and names #2215 as the fix, so a shim is the continuation of the PR author's
   framing rather than a fork of it.

**(ii) Omarchy-owned `linux-aarch64` rebuild through omarchy-pkgs — second, and the fallback.**
Evidence for acceptability: `linux-ptl` is precisely this (Arch PKGBUILD verbatim + patches,
`source: local`, `skip_build: true`, vendor-maintained, merged in minutes), and #124 shows a third
party adding to it is normal. Evidence against ranking it first: (a) a ~64 MB kernel build per
ALARM release, on an aarch64 builder omacom-io has never run in anger (§3a); (b) it would
*replace* ALARM's kernel for every aarch64 user rather than patch two files, which is a bigger
ask than #121 makes; (c) prior research (#2) found no config delta the G1q needs, so the package
would exist only to add two `install` lines — the PR body would have to say so, and DHH's habit is
to delete exactly that kind of package once upstream carries the lines. If it is ever needed
(X2/Glymur config fragment, or a G1q regression), name it `linux-aarch64` (same pkgbase, ALARM's
PKGBUILD verbatim, pkgrel suffix per omarchy-pkgs convention) — not `linux-x1e` — so the
configurator, hooks and `validate_boot()` need no changes and the package can be retired
silently. **Do not follow ALARM via `.omarchy/upstream.sh`**: that hook is for vendor binary
feeds with published checksums (README: "read checksums from whatever manifest the vendor
publishes"), not for tracking a PKGBUILD; `linux-ptl` is bumped by hand PRs.

**(iii) Shim only — third.** Mergeable on day one (the shape is fine), but it makes the gap
permanent, which contradicts every retirement in §5, and it leaves ALARM's kernel silently
unbootable for every other Arch-ARM Limine user. Rank it last; it is (i) without the half that
makes it self-retiring.

**What would flip this ranking:** a maintainer statement that they will not add a hook-only
package (none exists — §1), or ALARM closing a compliant #2215 successor on policy rather than
form (then (ii) becomes first). Size is the other lever: §1d shows every all-in-one ARM PR has
died and every small hardware PR has merged, so (i) is also the option that ships as the smallest
diff — one package plus one `install/hardware/` script — while (ii) drags a kernel build and a
hosting decision into the review.

### Conventions the whole Snapdragon layer must follow (each traced to a merged commit or PR #121)

1. **`uname -m` is the only architecture selector; x86_64 stays byte-identical.** PR #121's
   invariant; `profiledef.sh`, `detect_kernel()`, `OMARCHY_ARCH_DROP` all key on it. Add
   Snapdragon entries to the existing `case`/list rather than new selectors.
2. **Arch-specific files live under `configs/aarch64/` in the ISO and are staged only on that
   arch** (PR #121: `customize_airootfs.sh`, `linux.preset`, `zz-aarch64-live.conf` with explicit
   `file_permissions` entries). Snapdragon DTB/UKI/firmware staging goes there too.
3. **Hardware quirks live in `basecamp/omarchy` `install/hardware/<vendor>/<thing>.sh`, gated by a
   probe, run from `install/hardware/all.sh`**, using `omarchy-pkg-add` for packages and drop-ins
   (`/etc/mkinitcpio.conf.d/<hw>.conf`, `/etc/limine-entry-tool.d/zz-<hw>.conf`,
   `/etc/modules-load.d/<hw>.conf`, `/etc/udev/rules.d/99-omarchy-<hw>.rules`) — never edits to
   shared files. Precedent: `apple/fix-t2.sh`, `intel/ptl-kernel.sh`, `asus/fix-z13-touchpad.sh`.
4. **Probes are `bin/omarchy-hw-*` helpers** (`omarchy-hw-match` greps DMI `product_name` /
   `product_family`; `omarchy-hw-intel-ptl` greps `lspci`). A Snapdragon layer should add
   `omarchy-hw-qcom` / `omarchy-hw-snapdragon-x` (e.g. `/proc/device-tree/compatible` or
   `/sys/class/dmi/id/`) rather than inline probes, and must not hardcode
   `x1e80100-hp-elitebook-ultra-g1q` anywhere — `linux-t2` matches a PCI ID class, `linux-ptl` a
   GPU generation, not a model.
5. **Hardware packages are listed in `install/omarchy-other.packages`** under a commented heading
   so the ISO's offline mirror carries them (T2 and PTL blocks). Snapdragon firmware/UCM/shim
   packages go there, and — by PR #121's rule — x86-only ones go in `OMARCHY_ARCH_DROP` category 1.
6. **Packages: `.omarchy/package.json` with `source: local`; `arch=()` truthful** (`aarch64` only
   for a shim/firmware package, `any` if it has no binaries); AUR-derived changes as
   `.omarchy/patches/*.patch` (the #195 shape). A kernel, if ever, is `skip_build: true`.
7. **Every carried patch or workaround names its upstream destination and its retirement
   condition in-file** (`linux-ptl`'s commit trail, #124's "Upstream status", the
   `migrations/1784917531.sh` "until the race is fixed upstream" comment).
8. **Foreign repos are declared in the ISO pacman configs *and* `install/hardware/pacman.sh`**
   (the `[arch-mact2]` pattern) if the layer ever needs one; PR #121 already strips
   `[arch-mact2]`/`[multilib]` on aarch64, so an ALARM-only extra repo would be added in the same
   awk stage.
9. **Kernel churn is absorbed by `migrations/<epoch>.sh`** with idempotent guards (T2's
   `apple-bce` → `t2bce`), not by reinstall instructions.
10. **PR bodies carry a "Testing"/"Validation" section naming the hardware and kernel version**
    — every merged external kernel/hardware PR (#99, #116, #124's updates, #1657) has one; DHH
    merges on that, with no review comments.
11. **DHH's review rules from the first aarch64 PR (#876, verbatim in §1c):** "Don't want to
    maintain duplicate lists here" — patch the shared file during the aarch64 install instead of
    shipping an `aarch64_*.conf` twin; "It's fine to have rules for apps that aren't yet available
    on arm" — leave x86-only entries in shared configs rather than forking them; arch-only packages
    go "in the aarch64 group, so we don't install this for everyone else"; arch logic lives "in its
    own preflight/arm.sh file" (today: `install/hardware/`); "The fewer manual steps the better!" —
    no install guide in the repo, everything scripted ("a single script that does it all").
12. **Submodule changes are patches, never edits** (dhh, omarchy-iso#30: "If this is a change
    we're making, we have to make it as a patch") — the archiso GRUB filter stays a
    `builder/patches/*.patch`.
13. **Small, layered PRs.** #121 itself is four self-contained commits ("builder:", "configs:",
    "boot:", "installer:"); the Snapdragon layer should stack the same way and never be one
    "add Snapdragon support" PR (§1d).
14. **No emoji, no Co-Authored-By trailer for the user's commits** (user rule; upstream's own
    commits carry Claude trailers but that is their choice).

## 7. Findings for adjacent tickets (not this ticket's question)

- **#11 (kernel decision) — a concrete shim design that matches upstream shape:** package
  `alarm-kernel-pkgbase-shim` (or similar), `arch=('aarch64')`, `source: local`, one
  `PostTransaction` hook `Target = usr/lib/modules/*/` ordered before `90-mkinitcpio-install`,
  script: for each `usr/lib/modules/<ver>/` owned by `linux-aarch64` without `pkgbase`, write
  `pkgbase` and copy `/boot/Image` → `vmlinuz`, then run `mkinitcpio -P` and `limine-update`;
  exit 0 immediately when `pkgbase` exists. The `linux-ptl` PKGBUILD lines 138/141 are the
  canonical two lines to mirror.
- **#121 rebase risk:** oceanapplications has opened four more threads this week (omarchy-pkgs
  #195, #197, #199; basecamp/omarchy #8039; Zesko !63). If any merge, the "Snapdragon-specific
  files only" rule for our commits gets cheaper, but `phases_impl.py`/`context.py` will move.
  Watch #8039 in particular: it changes `install/post-install/pacman.sh` and
  `etc/mkinitcpio.conf.d/thunderbolt_module.conf` on aarch64 — the same files a Snapdragon
  layer would touch.
- **Limine on aarch64 needs Zesko !63 (or a carried patch in `limine-mkinitcpio-hook`)** —
  `limine-install` exits 0 with "The system is not x86_64.", so even with `pkgbase` present the
  entry tool writes no entries. This is a second silent no-boot on top of the pkgbase gap and is
  not on the map yet. omarchy-pkgs already carries `.omarchy/patches/` for AUR packages; the same
  mechanism works for this `source: local` package's git source if !63 stalls.
- **Hosting (#6 follow-up):** issue #199 is the public ask for `pkgs.omarchy.org/*/aarch64/`;
  #171 offers free GitHub ARM runners. Both unanswered. The map's "bake into the ISO first,
  host later" preference remains the only path that does not wait on a maintainer.
- **Apple Silicon demand is real and is what is driving the current ARM PRs** (#171 cites
  `omarchy-mac`; oceanapplications tests in Parallels on Apple Silicon, *not* on Snapdragon). No
  one upstream has tested #121 on physical ARM hardware. The G1q would be the first.
- **Contradiction with the map's Notes:** the map says "No upstream contact … until something
  works on real hardware — the PR *is* the contact." Consistent with §1, but note that upstream
  silence is the norm, not a signal: ten open ARM threads have no maintainer reply, and DHH's
  stated bar is "a fully verified setup" (#3449). The G1q live-USB + install result is exactly the
  evidence no ARM PR has yet carried; the PR body's "Testing" section is where it goes.
- **Apple Silicon is not out of scope for DHH even though it is for the plan** (2026-08-22 tweet
  vs `plans/aarch64-support.md`). The map's "Out of scope: Apple Silicon" is right for this layer
  but the PR should make the boundary explicit so it is not read as competing with the M1/M2 work.
- **`linux-firmware` / DTB packages:** ALARM's kernel ships DTBs in `/boot/dtbs/`; no omarchy
  precedent for a DTB package, and the T2/PTL layers never ship firmware outside
  `linux-firmware`/vendor packages (`apple-bcm-firmware` is a third-party AUR-style package
  pulled through `[arch-mact2]`). The map's extracted-blob package must therefore be an
  `install/hardware/` script or a `source: local` package with no redistributed blobs.

## Sources

- Ticket / map: https://github.com/JimmayVV/omarchy-iso/issues/16 , https://github.com/JimmayVV/omarchy-iso/issues/1
- PR #121: https://github.com/omacom-io/omarchy-iso/pull/121 (head `adf5a1f`, base `quattro` `268bac1`); `gh api repos/omacom-io/omarchy-iso/pulls/121/{reviews,comments,commits}`
- `plans/aarch64-support.md`: https://github.com/omacom-io/omarchy-iso/blob/quattro/plans/aarch64-support.md (`2d8ed3d` DHH 2026-04-30 "More plans")
- omarchy-iso T2 commits: `4639b85`, `234b54c`, `0638855`, `a202c81`, `a72a109`, `ed710a3`, `0631c05`, `a12bfea` (local clone, branch `quattro`)
- basecamp/omarchy PR #1657: https://github.com/basecamp/omarchy/pull/1657 ; `install/hardware/{all.sh,pacman.sh,apple/fix-t2.sh,intel/ptl-kernel.sh,asus/fix-z13-touchpad.sh}`, `install/omarchy-other.packages`, `migrations/{1785273276,1785944594,1784917531}.sh`, `bin/omarchy-hw-match`, `bin/omarchy-hw-intel-ptl`, `bin/omarchy-pkg-add`
- basecamp/omarchy PR #8039: https://github.com/basecamp/omarchy/pull/8039
- basecamp/omarchy ARM threads: issues #87, #803, #2330; PRs #367, #524 (`31ab6b49`), #628, #876, #1897, #3449, #5901, #7488, #7553, #7577, #7948, #7951; discussions #155, #452, #7739, #7956, #7960 (`gh api graphql`); `.github/ISSUE_TEMPLATE/{config,bug}.yml` (`54795a2f`, `bee90aa1`); `manual/44-mac-support.md`, `manual/49-omarchy-on.md` (`55434792`); releases via `gh api repos/basecamp/omarchy/releases`
- omarchy-iso review style: PRs #30, #59, #61, #67, #80, #87/#89, #92, #102 (closed-unmerged set); merger tally via GraphQL `mergedBy`
- DHH posts: https://x.com/dhh/status/1800125958714020110 , /1947139386144907621 , /1958766420436590867 , /1966940450394083619 , /2091216032450908668 (text re-fetched via `api.fxtwitter.com` 2026-08-24); https://world.hey.com/dhh/the-new-framework-13-hx370-68675e0e , /all-in-on-omarchy-at-37signals-68162450 , /panther-lake-is-the-real-deal-4bd731f1
- omarchy-pkgs ARM threads: PR #9 (jondkinney), #180 (omarchybot), README `1b14682`
- omarchy-pkgs: README.md; `build/Dockerfile`; `build/build.sh` (`should_build_for_arch`); `bin/sync-upstream`; `pkgbuilds/{limine-mkinitcpio-hook,limine-snapper-sync,linux-ptl,v4l2-relayd,dell-xps-touchpad-haptics}`; commits `f6cc3f3`, `78c1ef2`, `366d908`, `4d088d8`, `aca2584`, `c6eacf4`, `810efcc`, `929c8d0`, `7514a91`, `0f290b9`, `0c71613`, `aaa7610`, `01a566f`
- omarchy-pkgs PRs/issues: https://github.com/omacom-io/omarchy-pkgs/pull/7 , /pull/77 , /pull/99 , /pull/116 , /pull/117 , /pull/124 , /pull/131 , /pull/138 , /pull/171 , /pull/177 , /pull/195 , /pull/197 , /issues/199
- pkgs.omarchy.org probes (2026-08-24): `stable/aarch64/omarchy.db` 404, `edge/aarch64/omarchy.db` 404, `stable/x86_64/omarchy.db` 200
- ALARM: https://github.com/archlinuxarm/PKGBUILDs/pull/2215 (draft, one comment by graysky2 2026-08-24T18:10Z linking CONTRIBUTING); https://github.com/archlinuxarm/PKGBUILDs/blob/master/CONTRIBUTING.md
- Zesko limine-entry-tool MR !63: https://gitlab.com/Zesko/limine-entry-tool/-/merge_requests/63 (opened 2026-08-24, state `opened`)
- omarchy-mac: https://codeberg.org/malik-na/omarchy-mac
- Prior research: https://github.com/JimmayVV/omarchy-pkgs/blob/research/alarm-kernel/research/alarm-kernel-vs-linux-x1e.md , https://github.com/JimmayVV/omarchy-iso/blob/research/reproduce-pr121/research/reproduce-pr121.md
