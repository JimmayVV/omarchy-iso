# Research — silent WSA8845 speakers on Snapdragon X1E laptops under ALARM `linux-aarch64` 7.2-2

Research date: 2026-08-28. Read-only; no laptop touched, no commits.
Kernel sources quoted at tag **v7.2** (what ALARM `linux-aarch64 7.2-2` builds:
`_srcname=linux-7.2` in https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/linux-aarch64/PKGBUILD).
ALARM config quoted at the 7.2-2 commit
(https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/11ee3096f149/core/linux-aarch64/config).
Coordinator facts applied (2026-08-28): on the G1q the UNATTACHED devices on `soundwire@6b10000` are
`sdw:1:0:0217:0204:00:{0,1}` (`wsa884x-codec`, the two WSA8845 amps); the wcd938x on `6ad0000`/`6d30000`
is Attached; ALARM has `CONFIG_GPIO_SHARED=y`, `CONFIG_RESET_CONTROLLER=y`, `# CONFIG_RESET_GPIO is not set`.

---

## Bottom line

1. **(Q0/Q6) Root cause candidate, verified in source: ALARM's kernel has no `reset-gpio` provider, so the
   WSA8845 amps are never taken out of shutdown.** `wsa884x.c` at v7.2 requests its SD_N line as
   `devm_reset_control_get_optional_shared(dev, NULL)`; `drivers/reset/core.c` at v7.2 returns **NULL** for an
   optional request on a node that has `reset-gpios` but no `resets` when `CONFIG_RESET_GPIO` is unset
   (`if (!IS_ENABLED(CONFIG_RESET_GPIO)) return optional ? NULL : ERR_PTR(ret);`); the driver then falls back
   to a `powerdown-gpios` property the OmniBook/G1q and Yoga DTs do not have, and `wsa884x_reset_deassert()`
   becomes a no-op. The pinctrl state `spkr_01_sd_n_active` leaves LPI gpio12 `output-low` = asserted for
   `reset-gpios = <&lpass_tlmm 12 GPIO_ACTIVE_LOW>`. Amps stay in shutdown → never enumerate → UNATTACHED →
   `SWR CMD error … flushing fifo` on every bus access → card registers (codec *drivers* probed), PCM RUNNING,
   silence. ALARM: `# CONFIG_RESET_GPIO is not set` at 7.2-2, 7.1.5-2 and the 6.19 defconfig import.
   https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/codecs/wsa884x.c ,
   https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/reset/core.c ,
   https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/11ee3096f149/core/linux-aarch64/config
2. **(Q0a) Every stack on which X1E speakers are reported working builds `CONFIG_RESET_GPIO=m`:** mainline
   arm64 defconfig v7.2, Fedora rawhide aarch64, Ubuntu `7.0.0-15-generic` arm64 (built config from the
   buildinfo .deb), Debian `debian/latest` arm64, ironrobin `linux-x13s` 7.0.14, and Arch x86_64
   `config.x86_64` (7.1.11-arch1). ALARM is the outlier. See Q0a for URLs.
3. **(Q0b) The dependency was introduced deliberately and is not expressed in Kconfig:** commit `0dae534c4823`
   "ASoC: codecs: wsa884x: Allow sharing reset GPIO" (Krzysztof Kozlowski, 2024-01-29, v6.9) moved SD_N to the
   reset framework for shared lines; the same author enabled it in the defconfig in `cf30987a9ae9` "arm64:
   defconfig: enable reset-gpio driver as module" (2024-02-27: "Qualcomm X1E80100-CRD board uses shared reset
   GPIOs for speakers"). `config SND_SOC_WSA884X` only has `depends on SOUNDWIRE` / `select REGMAP_SOUNDWIRE`
   — nothing selects `RESET_GPIO`, so a distro that flips on WSA884X (ALARM PR #2204, 2026-06-11) gets a silent
   driver. https://github.com/torvalds/linux/commit/0dae534c48239be0a99092e46e1baade0cf3e04a ,
   https://github.com/torvalds/linux/commit/cf30987a9ae9a8a430f957f8516b2092f6bab29d
4. **(Q0d) A DT-only fallback exists in principle:** the binding still accepts `powerdown-gpios`
   (`oneOf: powerdown-gpios | reset-gpios`), the v7.2 driver still implements it, and ALARM's kernel has the
   new shared-GPIO machinery (`CONFIG_GPIO_SHARED=y` via `ARCH_QCOM select HAVE_SHARED_GPIOS`,
   `CONFIG_GPIO_SHARED_PROXY=m`) which turns two `powerdown-gpios` references to one pin into vote-based proxy
   descriptors. Whether the wsa884x fallback behaves correctly through the proxy is **UNVERIFIED** (no
   primary source shows it tested). See Q0d.
5. **(Q1) Speakers do work on these boards on mainline under other stacks** — Yoga DTS cover letter lists
   "Speakers"; Ubuntu bug 2149808 exists because X1E speakers play loudly enough to trip hardware protection;
   an OmniBook X14 user got sound on Ubuntu in March 2026. The fault is in this stack.
6. **(Q5) `PA Volume` caps at 6 because v7.2's machine driver calls `snd_soc_limit_volume(card, "SpkrLeft PA
   Volume", 6)`** (commit `0a5ee0e520ef`, 2026-04-22); alsa-lib clamps UCM's `cset 12` to the reported max via
   `check_range` and writes 6 without error. Not a silence cause.
7. **(Q2/Q3) No working x1e stack documents `tqftpserv` as an audio dependency**; the in-kernel pd-mapper
   (`m` on ALARM and Fedora) carries `x1e80100_domains` with `adsp_audio_pd`. ALARM ships none of
   tqftpserv/pd-mapper/qrtr/rmtfs; AUR does. The failure is at SoundWire enumeration, which is AP-side.
8. **(Q6d/Q7) Two loose ends are separate from the amps:** the G1q's internal mics are VA-macro DMICs whose
   bias routes name the (Attached) wcd938x `MIC BIAS1/3` — a distinct fault; and linux-firmware/Arch already
   ship the Yoga's `qcom/x1e80100/LENOVO/83ED/adsp_dtbs.elf`, so the extracted variant can be hash-checked.
   No primary source ties a wrong `adsp_dtbs.elf` to "ADSP runs, card registers, no sound" (UNVERIFIED).

---

## Q0. Root-cause verification (coordinator items a–d)

### Q0a. `CONFIG_RESET_GPIO` / `CONFIG_GPIO_SHARED_PROXY` across kernels

| Kernel / config | `RESET_GPIO` | `GPIO_SHARED` | `GPIO_SHARED_PROXY` | Source |
|---|---|---|---|---|
| ALARM `linux-aarch64` 7.2-2 (`11ee3096f149`) | **not set** | y | m | https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/11ee3096f149/core/linux-aarch64/config |
| ALARM 7.1.5-2 (`f9b4629b62f3`) | not set | — | — | https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/f9b4629b62f3/core/linux-aarch64/config |
| ALARM 6.19 defconfig import (`11dd76698485`) | not set (and `SND_SOC_WSA884X` not set) | — | — | https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/11dd76698485/core/linux-aarch64/config |
| mainline `arch/arm64/configs/defconfig` v7.2 | **m** (line 1740) | (def_bool) | (default m) | https://raw.githubusercontent.com/torvalds/linux/v7.2/arch/arm64/configs/defconfig |
| Fedora rawhide `kernel-aarch64-fedora.config` | **m** | — | m | https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-aarch64-fedora.config |
| Ubuntu `linux-buildinfo-7.0.0-15-generic_7.0.0-15.15_arm64.deb` → `/usr/lib/linux/7.0.0-15-generic/config` | **m** | y | m | https://launchpad.net/ubuntu/+archive/primary/+files/linux-buildinfo-7.0.0-15-generic_7.0.0-15.15_arm64.deb (this is the kernel in bug 2149808 where speakers over-drive) |
| Debian `debian/latest` `debian/config/arm64/config` | **m** (also `SND_SOC_WSA884X=m`) | — | — | https://salsa.debian.org/kernel-team/linux/-/raw/debian/latest/debian/config/arm64/config |
| ironrobin `linux-x13s` 7.0.14 (`codeberg.org/ironrobin/aarch64`) | **m** | — | m | https://codeberg.org/ironrobin/aarch64/raw/branch/main/linux-x13s/config (no x1e kernel exists there; `SND_SOC_X1E80100=m`, `WSA883X=m`, `WSA884X=m` in that config) |
| Arch x86_64 `config.x86_64` (7.1.11-arch1) | **m** | — | — | https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config.x86_64 |

Ubuntu's `debian.master/config/annotations` has no `CONFIG_RESET_GPIO` line (only `POWER_RESET_GPIO*`), so the
built config above is the authoritative Ubuntu value. The Ubuntu x1e "concept" kernel was not checked
(UNVERIFIED; the generic arm64 kernel already carries `m`).

### Q0b. The commits that created the dependency, and whether anything selects `RESET_GPIO`

- `0dae534c4823` "ASoC: codecs: wsa884x: Allow sharing reset GPIO" — Krzysztof Kozlowski, 2024-01-29 (v6.9):
  "On some boards with multiple WSA8840/WSA8845 speakers, the reset (shutdown) GPIO is shared between two
  speakers. Use the reset controller framework and its "reset-gpio" driver to handle this case. This allows
  bring-up and proper handling of all WSA884x speakers on X1E80100-CRD board." Adds `#include <linux/reset.h>`
  and `struct reset_control *sd_reset`. https://github.com/torvalds/linux/commit/0dae534c48239be0a99092e46e1baade0cf3e04a
  Series: "reset: gpio: ASoC: shared GPIO resets" v6,
  https://patchwork.ozlabs.org/project/devicetree-bindings/cover/20240129115216.96479-1-krzysztof.kozlowski@linaro.org/
- `cf30987a9ae9` "arm64: defconfig: enable reset-gpio driver as module" — same author, 2024-02-27:
  "Qualcomm X1E80100-CRD board uses shared reset GPIOs for speakers: each pair out of four speakers share the
  GPIO. Enable the reset-gpio driver which handles such case seamlessly." (adds `CONFIG_RESET_GPIO=m`).
  https://github.com/torvalds/linux/commit/cf30987a9ae9a8a430f957f8516b2092f6bab29d
- `01f6a84c7a3e` "reset: gpio: Fix missing gpiolib dependency for GPIO reset controller" (2024-03-25) —
  `RESET_GPIO` now `depends on GPIOLIB`, `select AUXILIARY_BUS`.
  https://github.com/torvalds/linux/commit/01f6a84c7a3eaabafd787608d630db31c6904f5c
- Matching wsa883x change: `cf6518224776` "ASoC: codecs: wsa883x: Handle shared reset GPIO for WSA883x
  speakers" — Mohammad Rafi Shaik, 2025-08-15 (QCS6490-RB3Gen2), same pattern; binding
  `126750523eac` "ASoC: dt-bindings: qcom,wsa8830: Add reset-gpios for shared line".
  https://github.com/torvalds/linux/commit/cf65182247761f7993737b710afe8c781699356b
- Kconfig at v7.2 — no dependency expressed:
  ```
  config SND_SOC_WSA884X
  	tristate "WSA884X Codec"
  	depends on SOUNDWIRE
  	select REGMAP_SOUNDWIRE
  ```
  (identical shape for `SND_SOC_WSA883X`). https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/codecs/Kconfig
  `RESET_GPIO` itself: `tristate "GPIO reset controller"`, `depends on GPIOLIB`, `select AUXILIARY_BUS`;
  help: "Typically for OF platforms this driver expects "reset-gpios" property."
  https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/reset/Kconfig
  So the only place the requirement is recorded is the defconfig commit; `make olddefconfig` on a config that
  never had it (ALARM's) leaves it `n`, silently.

### Q0c. Arch Linux ARM packaging history and the "match Arch" argument

- GitHub issue/PR search `repo:archlinuxarm/PKGBUILDs RESET_GPIO`: **0 results**
  (https://api.github.com/search/issues?q=repo:archlinuxarm/PKGBUILDs+RESET_GPIO).
- Snapdragon-related PRs on the tracker: #2094 "core/linux-aarch64: Enable Qualcomm X1E config options"
  (andersson, 2025-03-05; diff turns on `CONFIG_SND_SOC_X1E80100=m`, not RESET_GPIO)
  https://github.com/archlinuxarm/PKGBUILDs/pull/2094 ; #2174 "core/linux-aarch64-rc: Enable Snapdragon laptop
  drivers" (andersson, 2026-01-17) https://github.com/archlinuxarm/PKGBUILDs/pull/2174 ; #2152 "add usb
  repeater and display modules for snapdragon x" (merged 2025-10-25)
  https://github.com/archlinuxarm/PKGBUILDs/pull/2152 ; **#2204 "linux-aarch64-rc: enable configs for ASUS
  Zenbook A14 (UX3407QA)" (aotot, merged 2026-06-11) — this is the PR that flipped
  `# CONFIG_SND_SOC_WSA884X is not set` → `CONFIG_SND_SOC_WSA884X=m`, without `RESET_GPIO`.**
  https://github.com/archlinuxarm/PKGBUILDs/pull/2204
- Config git log for `core/linux-aarch64/config` (atom): `11dd76698485` "core/linux-aarch64 arm64 defconfig
  v6.19" (jimmyhon, 2026-02-10) — that import still had RESET_GPIO unset, i.e. the ALARM config is not a
  straight copy of mainline defconfig (which has had `RESET_GPIO=m` since 6.9).
  https://github.com/archlinuxarm/PKGBUILDs/commits/master/core/linux-aarch64/config
- Arch x86_64 `linux` (7.1.11-arch1) sets `CONFIG_RESET_GPIO=m`
  (https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config.x86_64), so "match Arch
  and mainline defconfig" both hold for an ALARM PR.

### Q0d. Could a `powerdown-gpios` DT fallback work without a kernel rebuild?

Facts at v7.2:
- The fallback is live code, not legacy-only: `wsa884x_get_reset()` tries the reset framework first and,
  on NULL, does `devm_gpiod_get_optional(dev, "powerdown", GPIOD_OUT_HIGH)`; `wsa884x_reset_deassert()` then
  does `gpiod_direction_output(sd_n, 0)`. The in-code comment: "use the backwards compatible way for
  powerdown-gpios, which does not handle sharing GPIO properly" (written in 2024, before gpiolib-shared).
  https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/codecs/wsa884x.c
- The binding still allows it: `powerdown-gpios: description: Powerdown/Shutdown line to use (pin SD_N)` and
  `oneOf: - required: [powerdown-gpios]  - required: [reset-gpios]`; its own example uses `powerdown-gpios`.
  https://raw.githubusercontent.com/torvalds/linux/v7.2/Documentation/devicetree/bindings/sound/qcom,wsa8840.yaml
- Shared-GPIO core (new since 6.19): `config GPIO_SHARED def_bool y depends on HAVE_SHARED_GPIOS`, and
  `ARCH_QCOM` does `select HAVE_SHARED_GPIOS` (`arch/arm64/Kconfig.platforms` line 331) — hence ALARM's
  `CONFIG_GPIO_SHARED=y`. `config GPIO_SHARED_PROXY tristate "Proxy driver for non-exclusive GPIOs" default m`
  — ALARM `m`. https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/gpio/Kconfig ,
  https://raw.githubusercontent.com/torvalds/linux/v7.2/arch/arm64/Kconfig.platforms
- How it decides: `gpiolib-shared.c` walks the whole DT at `postcore_initcall` (`gpio_shared_of_scan`),
  records every `*-gpios` reference per (controller, offset), and keeps only entries that are "really shared":
  `num_nodes > 2 → true`; exactly two references → true unless one of them is the synthetic
  `reset-gpios` proxy ref (`gpio_shared_entry_is_really_shared`). For a pin referenced by two amps'
  `powerdown-gpios` that is 2 real refs → shared → proxy auxiliary devices are created when the LPI gpiochip
  registers, and consumer lookups are redirected via `gpio_shared_add_proxy_lookup()`.
  https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/gpio/gpiolib-shared.c
- Proxy semantics (`gpio-shared-proxy.c`): first `direction_output` with `usecnt == 1` sets the physical line
  and records `def_val`; further users vote — any consumer setting `value != def_val` flips the line to the
  non-default value and increments `votecnt`; the line returns to `def_val` only when the last vote is
  withdrawn. For two amps requesting `GPIOD_OUT_HIGH` (asserted) then deasserting (0), the first deassert
  drives SD_N high and the second amp's deassert is a second vote. Reads return the physical value.
  https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/gpio/gpio-shared-proxy.c
- Caveats: (i) no primary source shows `wsa884x` + `powerdown-gpios` + the shared proxy tested on any board —
  **UNVERIFIED**; (ii) the `gpio-shared-proxy` module must autoload (auxiliary-bus match) before the amps
  probe, otherwise the amps' `gpiod_get` defers; (iii) it means carrying a non-upstream DTB delta on every
  supported laptop. With `reset-gpios` as today, the same scan creates 3 refs (two amps + reset proxy ref) and
  proxies for that pin, but the reset core never asks for it while `RESET_GPIO` is off, so nothing changes.
- Note on the wcd938x (why it is Attached): it uses `devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW)` directly
  and toggles it in `wcd938x_reset()`; no reset-framework provider is needed
  (https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/codecs/wcd938x.c lines 3206-3262).

## Q1. Do speakers work on these exact boards on mainline elsewhere?

**Lenovo Yoga Slim 7x** — DTS submission cover letter (Srinivas Kandagatla, Linaro, 2024-07-03):
> "This patchset adds support to Lenovo Yoga Slim 7x based on x1e80100 SoC."
> Working: "Keyboard, touch screen Display, Speakers. all 3 usb ports. WLAN GPU NVMe"
> Not working: "touchpad. 4 x dmics Battery level (Does not work)"
> "All the firmwares are copied from windows for testing."
https://patchew.org/linux/20240703-yoga-slim7x-v1-0-7aa4fd5fdece@linaro.org/

**HP OmniBook X 14** — DTS v2 cover letter (Jens Glathe, 2024-11-30) lists "ADSP and CDSP" and
"Audio definition (works via USB)" — speakers were not claimed at submission.
https://patchew.org/linux/20241130-hp-omnibook-x14-v2-0-72227bc6bbf4@oldschoolsolutions.biz/
Ubuntu-concept bug 2084960 tracks it further: Jens Glathe (Oct 2024) listed "speakers / soundwire /
headphone (Sound via USB /BT works fine)" as not working; Oskar Enoksson (March 2026) reported
`Loaded FW: qcom/x1e80100/X1E80100-HP-OMNIBOOK-X14-tplg.bin` after adding Ubuntu's
`snd_soc_x1e80100.i_accept_the_danger` parameter, and on 2026-03-28: "I got the sound working, but
only after doing an sudo rsync -avhc ucm2/codecs/ /usr/share/alsa/ucm2/codecs/" (Ubuntu's
alsa-ucm-conf lacked `ucm2/codecs/wsa884x`; Arch 1.2.16.1 has it).
https://bugs.launchpad.net/ubuntu-concept/+bug/2084960
Note: `i_accept_the_danger` is an Ubuntu SAUCE parameter — `grep -i danger` on
https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/qcom/x1e80100.c returns nothing, so it
plays no part on ALARM.

The HP EliteBook Ultra G1q DTS `#include`s the OmniBook DTS whole (ticket thread), so the OmniBook
evidence applies. jglathe on alsa-ucm-conf PR #531 (2025-04-01): "I have a positive report for the HP
Elitebook G1q" https://github.com/alsa-project/alsa-ucm-conf/pull/531.

**ThinkPad T14s (same 2×WSA8845-on-swr0 topology, same `reset-gpios` pattern)** — jhovold wiki:
"| Audio (headset) | 6.14 (6.16) |", and under Audio issues "Active speaker protection not enabled,
make sure to keep volume low" — i.e. speakers play. Userspace: "alsa-ucm-conf 1.2.14",
"linux-firmware 20250410". https://raw.githubusercontent.com/wiki/jhovold/linux/T14s.md

**Ubuntu 26.04 (kernel 7.0)** — bug 2149808 "Qualcomm X1E: Speaker overdrive causes hardware
protection shutdown": "playing music and turning the speaker up to 100% causes a hardware safety
mechanism to trigger and shut down the speakers entirely until the next reboot." Fixed by
"SAUCE: ASoC: qcom: x1e80100: limit speaker volumes", released in 7.0.0-15.15.
https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2149808 — speakers clearly produce sound there.
The same limit went upstream and is in v7.2 (see Q5).

**Fedora** — bring-up thread, Gurney Buchanan on a Yoga Slim 7x (2025-06-20): "The only things that do
not work are: Speakers (patch available but can cause damage to device)... Microphone (patch available
to dtb)". https://discussion.fedoraproject.org/t/snapdragon-x-elite-fedora-42-system-bring-up-and-looking-for-collaborators-or-sigs/153631
Fedora's install wiki: "Linux needs to reboot the ADSP co-processor with a full featured firmware for
things like audio and battery-monitoring support." https://fedoraproject.org/wiki/Snapdragon_WoA_Laptop_Install

**Ubuntu 25.04/25.10 FAQ** (older): "lots of features are not yet supported (built-in speakers,
webcam, )". https://discourse.ubuntu.com/t/faq-ubuntu-25-04-25-10-on-snapdragon-x-elite/61016

Verdict: speaker output on the OmniBook/T14s topology and on the Yoga is demonstrated on mainline-based
kernels by Linaro, Canonical and end users. The fault is in this stack.

## Q2. What a working Arch-family / other-distro x1e install ships that ALARM + Omarchy does not

**ironrobin** — all repos moved to Codeberg. Repository list at https://codeberg.org/ironrobin :
`archiso-x13s` ("archiso installer customized for the X13s laptop and Windows Dev Kit 2023"),
`firmworm` ("a cross-OS firmware extraction utility for Snapdragon laptops"), `aarch64` ("Arch Linux
package repository"), `dtbsync`, `arch-stubble`, `archports-aarch64-container`, `squashfs-tools-mingw`,
`dotfiles`. The `aarch64` package repo contains `linux-x13s`, `linux-volterra`, `archinstall-aarch64`,
`dtbsync`, `mkinitcpio-archiso`, libisoburn/libisofs/libburn — **no x1e kernel and no
tqftpserv/pd-mapper/qrtr/rmtfs packages** (https://codeberg.org/ironrobin/aarch64). The old GitHub
`archiso-x13s` is archived as of 2026-08-03 (https://github.com/ironrobin/archiso-x13s/wiki/Feature-Support).
There is no ironrobin x1e kernel PKGBUILD to compare — UNVERIFIED that any exists elsewhere.

**Arch Linux ARM** — `archlinuxarm.org/packages/aarch64/{tqftpserv,pd-mapper,qrtr,rmtfs,qrtr-ns}` all
return HTTP 404; `alsa-ucm-conf 1.2.16.1-1` and `linux-firmware-qcom 20260810-2` exist
(https://archlinuxarm.org/packages/aarch64/alsa-ucm-conf, https://archlinuxarm.org/packages/aarch64/linux-firmware-qcom).

**AUR** (RPC v5 info, 2026-08-28): `tqftpserv 1.2-1`, `pd-mapper 1.1-1`, `qrtr 1.2-1`, `rmtfs 1.2-1`
(maintainer supertecnogym), plus `tqftpserv-git`, `pd-mapper-git` (depends `qrtr`), `qrtr-git`.
https://aur.archlinux.org/rpc/v5/info?arg[]=tqftpserv&arg[]=pd-mapper&arg[]=qrtr&arg[]=rmtfs

**Fedora** — source packages exist for `tqftpserv`, `qrtr`, `pd-mapper`, `rmtfs`,
`qcom-firmware-extract` (https://src.fedoraproject.org/rpms/tqftpserv etc. all HTTP 200). Fedora's
wiki install flow uses `qcom-firmware-extract` and installs `*.mbn*`/`*.elf*` into the initramfs
(https://fedoraproject.org/wiki/Snapdragon_WoA_Laptop_Install). Fedora kernel config (rawhide):
`CONFIG_RESET_GPIO=m`, `CONFIG_QCOM_PD_MAPPER=m`, `CONFIG_SND_SOC_WSA884X=m`, `CONFIG_SOUNDWIRE_QCOM=m`
(https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-aarch64-fedora.config).

**Ubuntu** — `protection-domain-mapper` and `qrtr` were MIR'd for Qualcomm laptops
(https://bugs.launchpad.net/bugs/2038942); `tqftpserv` is packaged
(https://launchpad.net/ubuntu/+source/tqftpserv); they were added to desktop seeds "only intended for
qualcomm desktop system" (https://bugs.launchpad.net/ubuntu/+source/ubuntu-meta/+bug/2063371).
Ubuntu's `debian.master/config/annotations` for resolute has no `CONFIG_RESET_GPIO` line (only
`CONFIG_SND_SOC_WSA884X ... 'arm64': 'm'`), so its value there is UNVERIFIED.
https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/resolute/plain/debian.master/config/annotations

**jhovold (Linaro, upstream x1e maintainer) userspace list** — X13s: "alsa-ucm-conf 1.2.11",
"linux-firmware 20241210", "~~Qualcomm protection-domain mapper daemon (pd-mapper)~~ (not needed since
6.11)"; T14s: "alsa-ucm-conf 1.2.14", "linux-firmware 20250410". No tqftpserv, rmtfs or qrtr-ns on either
page. https://raw.githubusercontent.com/wiki/jhovold/linux/X13s.md ,
https://raw.githubusercontent.com/wiki/jhovold/linux/T14s.md

**Forks carrying 7.2 audio fixes** — `ooaklee/linux-surface-pro-11-oe` builds jglathe's
`sp11/integration-7.2.x` branch ("7.2.0-jg-0sp11v7") with a "wsa884x 2S/4-ohm PA-recovery profile,
which fixes the left-speaker audio wedge at sustained full volume" — a volume-related fix, not an
enumeration fix. https://github.com/ooaklee/linux-surface-pro-11-oe

Audio-relevant differences summary (stock ALARM + Omarchy vs. the above):

| Item | ALARM 7.2-2 + Omarchy | Fedora / defconfig / jhovold |
|---|---|---|
| `CONFIG_RESET_GPIO` | **not set** | Fedora `m`, arm64 defconfig `m` |
| `CONFIG_SND_SOC_WSA884X` | `m` (was **not set** in ALARM's 6.19 config) | `m` |
| pd-mapper | in-kernel `m` | in-kernel `m` (jhovold: daemon not needed since 6.11) |
| tqftpserv / rmtfs / qrtr daemons | absent | packaged by Fedora/Ubuntu; not listed as audio deps by jhovold |
| alsa-ucm-conf | 1.2.16.1 (has `codecs/wsa884x`) | jhovold requires ≥1.2.14 |
| linux-firmware | 20260810-2 | jhovold requires ≥20250410 |

## Q3. Does the ADSP need `tqftpserv` / `pd-mapper` / `rmtfs` for playback?

`tqftpserv` README: "The main purpose of tqftpserv is to serve files from the Linux file system to
other processors on the Qualcomm SoCs as requested." Read-only requests under
`/readonly/firmware/image/` are translated to `/lib/firmware/…` using each remoteproc's `firmware-name`;
the README's examples are all modem (`modem_pr/so/901_0_0.mbn`).
https://raw.githubusercontent.com/linux-msm/tqftpserv/master/README.md ; translation code
https://raw.githubusercontent.com/linux-msm/tqftpserv/master/translate.c ("Strips
/readonly/firmware/image/ and searches among remoteproc firmware", tries `/lib/firmware/updates/`, `.zst`).

`linux-msm/pd-mapper` has no README (raw README.md returns 404;
https://github.com/linux-msm/pd-mapper). The kernel replacement:
```
config QCOM_PD_MAPPER
	tristate "Qualcomm Protection Domain Mapper"
	...
	default QCOM_RPROC_COMMON
	help
	  The Protection Domain Mapper maps registered services to the domains
	  and instances handled by the remote DSPs. This is a kernel-space
	  implementation of the service. It is a simpler alternative to the
	  userspace daemon.
```
https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/soc/qcom/Kconfig
and `qcom_pd_mapper.c` at v7.2 has
`x1e80100_domains[] = { &adsp_audio_pd, &adsp_root_pd, &adsp_charger_pd, &adsp_sensor_pd, &cdsp_root_pd, NULL }`
matched by `{ .compatible = "qcom,x1e80100", .data = x1e80100_domains }`; it is an auxiliary-bus driver
(`module_auxiliary_driver(qcom_pdm_drv)`), so `=m` autoloads.
https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/soc/qcom/qcom_pd_mapper.c

ALARM 7.2-2: `CONFIG_QCOM_PD_MAPPER=m`, `CONFIG_QCOM_PDR_HELPERS=m`, `CONFIG_QCOM_QSEECOM=y`,
`CONFIG_QCOM_QSEECOM_UEFISECAPP=y`, `CONFIG_QRTR=m`, `CONFIG_QRTR_SMD=m`.
On the G1q the APM service came up (`qcom-apm gprsvc:service:2:1` loaded the topology — ticket
thread), which is the audio PD registering, so pd-mapper is functioning.

Concretely: **no primary source documents "pd-mapper present, tqftpserv absent ⇒ card registers,
capture works, playback silent"** — UNVERIFIED. The kernel does not log unanswered TFTP requests
(the TFTP client is DSP firmware talking QRTR to userspace; nothing in `qcom_q6v5_pas.c` or the
`gpr`/`q6apm` drivers references TFTP). jhovold's wikis, the reference for working x1e audio, do not
list tqftpserv at all. Given Q6, the observed failure is at SoundWire enumeration, which is entirely
AP-side (`drivers/soundwire/qcom.c`) and does not depend on tqftpserv.

## Q4. ALARM `linux-aarch64` 7.2-2 config for audio (vs Fedora)

Config file named in the PKGBUILD as `config` (`cat "${srcdir}/config" > ./.config`). Values at the
7.2-2 commit `11ee3096f149`; master (7.2.1-1, commit `ae6874bbcbc9` "add options") differs only in
CAN_ROCKCHIP_CANFD, SUN50I_IOMMU, PHY_ROCKCHIP_SAMSUNG_DCPHY and ANDROID_BINDER_DEVICES.
https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/11ee3096f149/core/linux-aarch64/config

| Symbol | ALARM 7.2-2 | Fedora rawhide | Note |
|---|---|---|---|
| SND_SOC_QCOM | m | m | |
| SND_SOC_X1E80100 | m | m | `depends on QCOM_APR && SOUNDWIRE`, selects QDSP6, QCOM_COMMON, QCOM_SDW (sound/soc/qcom/Kconfig) |
| SND_SOC_SC8280XP | m | m | |
| SND_SOC_QCOM_COMMON / QCOM_SDW | m / m | (selected) | |
| SND_SOC_QDSP6_* (COMMON, CORE, AFE, AFE_DAI, AFE_CLOCKS, ADM, ROUTING, ASM, ASM_DAI, APM_DAI, APM_LPASS_DAI, APM, PRM_LPASS_CLOCKS, PRM), SND_SOC_QDSP6 | all m | QDSP6=m, QDSP6_USB=m | |
| SND_SOC_TOPOLOGY | y | (implied) | |
| SND_SOC_WSA884X / WSA883X / WSA881X | m / m / m | m / m / not set | ALARM 6.19 config: `# CONFIG_SND_SOC_WSA884X is not set` |
| SND_SOC_WCD938X / WCD938X_SDW | m / m | (WCD938X_SDW=m) | |
| SND_SOC_WCD939X_SDW | not set | m | irrelevant for wcd938x boards |
| SND_SOC_WCD937X_SDW | not set | m | irrelevant |
| SND_SOC_LPASS_{MACRO_COMMON,WSA_MACRO,VA_MACRO,RX_MACRO,TX_MACRO} | m | m | |
| SOUNDWIRE / SOUNDWIRE_QCOM | m / m | m / m | |
| SOUNDWIRE_GENERIC_ALLOCATION | absent (hidden symbol) | m | selected by Intel/AMD masters only |
| QCOM_PD_MAPPER / QCOM_PDR_HELPERS | m / m | m | |
| QCOM_APR | m | m | GPR lives under QCOM_APR |
| QCOM_Q6V5_PAS / Q6V5_COMMON / RPROC_COMMON | m | m | |
| QRTR / QRTR_SMD | m / m | m / m | |
| QCOM_SMD_RPM, SMP2P, SMEM, SYSMON | y, y, y, m | m, m, m, m | |
| COMMON_CLK_QCOM | y | y | |
| CLK_X1E80100_GCC / TCSRCC / DISPCC / GPUCC / CAMCC | y / y / m / m / m | same | (`drivers/clk/qcom/Kconfig` symbols for x1e80100) |
| SC_LPASSCC_8280XP | m | m | provides `qcom,sc8280xp-lpassaudiocc`/`lpasscc` used by x1e80100 swr resets (`lpasscc-sc8280xp.c`) |
| PINCTRL_X1E80100 | y | y | |
| PINCTRL_LPASS_LPI / SM8550_LPASS_LPI | m / m | m / m | x1e80100 uses fallback `qcom,sm8550-lpass-lpi-pinctrl` |
| REGULATOR_QCOM_RPMH | y | y | |
| INTERCONNECT_QCOM / _X1E80100 / _RPMH | y / y / y | y / y | |
| QCOM_QSEECOM / _UEFISECAPP | y / y | y / y | |
| DMI | y | y | |
| **RESET_GPIO** | **not set** | **m** | arm64 defconfig v7.2: `CONFIG_RESET_GPIO=m` |

All module-vs-builtin differences are irrelevant to probe ordering (deferral handles it). The only
audio-path symbol ALARM lacks that Fedora and the upstream defconfig carry is `CONFIG_RESET_GPIO`
(Kconfig text: "This enables a generic reset controller for resets attached via GPIOs. Typically for OF
platforms this driver expects "reset-gpios" property.",
https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/reset/Kconfig).
Sources: Fedora https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-aarch64-fedora.config ;
defconfig https://raw.githubusercontent.com/torvalds/linux/v7.2/arch/arm64/configs/defconfig ;
clk Kconfig https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/clk/qcom/Kconfig ;
pinctrl Kconfig https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/pinctrl/qcom/Kconfig ;
interconnect https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/interconnect/qcom/Kconfig.
ironrobin config: none exists for x1e (Q2).

## Q5. `wsa884x` PA Volume range and the UCM `cset 12`

Codec control at v7.2 (`sound/soc/codecs/wsa884x.c` lines 1734-1739):
```c
static const DECLARE_TLV_DB_SCALE(pa_gain, -900, 150, -900);
...
	SOC_SINGLE_RANGE_TLV("PA Volume", WSA884X_DRE_CTL_1,
			     WSA884X_DRE_CTL_1_CSR_GAIN_SHIFT,
			     0x0, 0x1f, 1, pa_gain),
```
i.e. 0..31 steps of 1.5 dB from −9 dB. https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/codecs/wsa884x.c
The wsa884x.c history at v7.2 has no commit touching that range
(https://github.com/torvalds/linux/commits/v7.2/sound/soc/codecs/wsa884x.c).

The 0..6 cap is the **machine driver**, `sound/soc/qcom/x1e80100.c` at v7.2:
```c
	case WSA_CODEC_DMA_RX_0:
	case WSA_CODEC_DMA_RX_1:
		/*
		 * Set limit of -3 dB on Digital Volume and 0 dB on PA Volume
		 * to reduce the risk of speaker damage until we have active
		 * speaker protection in place.
		 */
		snd_soc_limit_volume(card, "WSA WSA_RX0 Digital Volume", 81);
		...
		snd_soc_limit_volume(card, "SpkrLeft PA Volume", 6);
		snd_soc_limit_volume(card, "SpkrRight PA Volume", 6);
```
Commit `0a5ee0e520ef` "ASoC: qcom: x1e80100: limit speaker volumes", Tobias Heider (Canonical),
2026-04-22, Tested/Reviewed-by Srinivas Kandagatla: "x1e80100 machines use wsa884x amplifiers which
expose a linear scale from -9 dB to 9 dB with a 1.5 dB step size giving us 0 dB = -9 dB + 6 * 1.5 dB."
https://github.com/torvalds/linux/commit/0a5ee0e520eff98ee2b4568194562870877b050f
`snd_soc_limit_volume` sets `mc->platform_max`; `soc_info_volsw` reports `max = platform_max` and
`soc_mixer_valid_ctl` returns `-EINVAL` for `val > platform_max`
(https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/soc-ops.c lines 150-193, 446-472).

alsa-ucm-conf `ucm2/codecs/wsa884x/two-speakers/SpeakerSeq.conf` — **identical** at `master` and
`v1.2.16.1` (the version ALARM ships): `cset "name='SpkrLeft PA Volume' 12"` and `SpkrRight … 12`
inside `EnableSequence`.
https://raw.githubusercontent.com/alsa-project/alsa-ucm-conf/v1.2.16.1/ucm2/codecs/wsa884x/two-speakers/SpeakerSeq.conf

What alsa-lib does with 12 on a 0..6 control: `execute_cset()` calls `snd_ctl_elem_info()` then
`snd_ctl_ascii_value_parse(ctl, value, info, pos)`
(https://raw.githubusercontent.com/alsa-project/alsa-lib/master/src/ucm/main.c), whose INTEGER branch
is `get_integer(&ptr, snd_ctl_elem_info_get_min(info), snd_ctl_elem_info_get_max(info))` and
`get_integer` ends with `val = check_range(val, min, max)` where
`#define check_range(val, min, max) ((val < min) ? (min) : ((val > max) ? (max) : (val)))`
(https://raw.githubusercontent.com/alsa-project/alsa-lib/master/src/control/ctlparse.c lines 51-79).
So the write is **silently clamped to 6 and succeeds**; the sequence continues. (Had it reached the
kernel as 12, `-EINVAL` would make ucm log `unable to execute cset` and abort the whole
EnableSequence at that line — lines 841-844 of ucm/main.c.)
The ticket's observation that the amps "sit at 1" is not explained by clamping; with the amps
UNATTACHED the codec regmap is cache-only (`wsa884x_update_status`: `regcache_cache_only(…, true)`),
so no PA Volume value reaches hardware regardless.

alsa-ucm-conf tracker: GitHub search for "PA Volume" (17 hits) and `wsa884x` (3 hits: #725, #450, #369)
has no issue or PR about 12 exceeding the x1e80100 limit
(https://api.github.com/search/issues?q=repo:alsa-project/alsa-ucm-conf+%22PA+Volume%22).

## Q6 (retargeted). Why the WSA8845 amps never attach on `soundwire@6b10000`

### 6a. Bus identities (hamoa.dtsi, v7.2)

| Label | Node | `label` | Children on OmniBook/G1q | sdw part id |
|---|---|---|---|---|
| `swr0` | `soundwire@6b10000` | `"WSA"` | `left_spkr`/`right_spkr` `sdw20217020400` | `0217:0204` |
| `swr1` | `soundwire@6ad0000` | `"RX"` | `wcd_rx` `sdw20217010d00` | `0217:010d` |
| `swr2` | `soundwire@6d30000` | `"TX"` | `wcd_tx` `sdw20217010d00` | `0217:010d` |
| `swr3` | `soundwire@6ab0000` | (WSA2) | disabled on OmniBook; Yoga right woofer/tweeter | |

All four are `status = "disabled"` in the SoC dtsi and enabled per board.
https://raw.githubusercontent.com/torvalds/linux/v7.2/arch/arm64/boot/dts/qcom/hamoa.dtsi ,
https://raw.githubusercontent.com/torvalds/linux/v7.2/arch/arm64/boot/dts/qcom/x1-hp-omnibook-x14.dtsi
Device names are `sdw:%01x:%01x:%04x:%04x:%02x:%01x` = ctrl:link:mfg:part:class:unique
(https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/soundwire/slave.c); `controller_id`
is an IDA allocated in probe order (`bus->controller_id = rc` in
https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/soundwire/bus.c). So
`sdw:1:0:0217:0204:00:0/1` = WSA8845 left/right, on the second-probed controller, which the log
identifies as `6b10000` = `swr0` "WSA".

### 6b. The amps' shutdown line goes through the reset framework — and ALARM has no provider

OmniBook/G1q DT (`x1-hp-omnibook-x14.dtsi`):
```dts
&lpass_tlmm {
	spkr_01_sd_n_active: spkr-01-sd-n-active-state {
		pins = "gpio12";  function = "gpio";  drive-strength = <16>;  bias-disable;  output-low;
	};
};
&swr0 {
	pinctrl-0 = <&wsa_swr_active>, <&spkr_01_sd_n_active>;
	...
	left_spkr: speaker@0,0 {
		compatible = "sdw20217020400";
		reset-gpios = <&lpass_tlmm 12 GPIO_ACTIVE_LOW>;
		vdd-1p8-supply = <&vreg_l15b_1p8>;  vdd-io-supply = <&vreg_l12b_1p2>;
		qcom,port-mapping = <1 2 3 7 10 13>;
	};
	right_spkr: speaker@0,1 { ... reset-gpios = <&lpass_tlmm 12 GPIO_ACTIVE_LOW>; ... };
};
```
Yoga: identical pattern on `lpass_tlmm 12` (swr0) and `lpass_tlmm 13` (swr3)
(https://raw.githubusercontent.com/torvalds/linux/v7.2/arch/arm64/boot/dts/qcom/x1e80100-lenovo-yoga-slim7x.dts
lines 1297-1341).

Driver, v7.2 `wsa884x.c`:
```c
static int wsa884x_get_reset(struct device *dev, struct wsa884x_priv *wsa884x)
{
	wsa884x->sd_reset = devm_reset_control_get_optional_shared(dev, NULL);
	if (IS_ERR(wsa884x->sd_reset))
		return dev_err_probe(dev, PTR_ERR(wsa884x->sd_reset), "Failed to get reset\n");
	else if (wsa884x->sd_reset)
		return 0;
	/*
	 * else: NULL, so use the backwards compatible way for powerdown-gpios,
	 * which does not handle sharing GPIO properly.
	 */
	wsa884x->sd_n = devm_gpiod_get_optional(dev, "powerdown", GPIOD_OUT_HIGH);
	...
}
...
static void wsa884x_reset_deassert(struct wsa884x_priv *wsa884x)
{
	if (wsa884x->sd_reset)
		reset_control_deassert(wsa884x->sd_reset);
	else
		gpiod_direction_output(wsa884x->sd_n, 0);
}
```
This shape dates from `0dae534c4823` "ASoC: codecs: wsa884x: Allow sharing reset GPIO" (Krzysztof
Kozlowski, 2024-02-21; series "reset: gpio: ASoC: shared GPIO resets",
https://patchwork.ozlabs.org/project/devicetree-bindings/cover/20240129115216.96479-1-krzysztof.kozlowski@linaro.org/):
each pair of WSA8845s shares SD_N, non-exclusive GPIOs are unsupported, so the DT property became
`reset-gpios` served by the reset framework's `reset-gpio` driver.

Reset core, v7.2 `drivers/reset/core.c` (`__of_reset_control_get`), when the node has no `resets`
property:
```c
	if (ret) {
		if (!IS_ENABLED(CONFIG_RESET_GPIO))
			return optional ? NULL : ERR_PTR(ret);
		...
		ret = fwnode_property_get_reference_args(fwnode, "reset-gpios", "#gpio-cells", 0, 0, &args);
		...
		ret = __reset_add_reset_gpio_device(fwnode, &args);
```
https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/reset/core.c (lines 1160-1185)

ALARM configs: `# CONFIG_RESET_GPIO is not set` at 7.2-2 (`11ee3096f149`), 7.1.5-2 (`f9b4629b62f3`)
and the 6.19 defconfig import (`11dd76698485`); `CONFIG_RESET_CONTROLLER=y`, `RESET_QCOM_AOSS=y`,
`RESET_QCOM_PDC=y`, `RESET_SIMPLE=y`.
Fedora: `CONFIG_RESET_GPIO=m`. arm64 defconfig v7.2: `CONFIG_RESET_GPIO=m`.

Chain on ALARM: `optional` request → NULL (no error, no log) → fallback `powerdown-gpios` absent →
`sd_n` NULL → `wsa884x_reset_deassert` is a no-op → SD_N stays where pinctrl put it (`output-low`,
i.e. asserted for an ACTIVE_LOW reset; `reset-gpio.c` deassert writes logical 0 = physical high) →
amps never power up → never enumerate → UNATTACHED → every controller command to them is unanswered
→ `qcom_swrm_irq_handler: SWR CMD error, fifo status …, flushing fifo` (string at
https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/soundwire/qcom.c line 798) → card
still registers because the codec *drivers* probed fine and the regmap is cache-only until
ATTACHED (`wsa884x_update_status`).

Why the wcd938x is fine: it takes its reset **directly** as a GPIO —
`wcd938x->reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW);` and toggles it in
`wcd938x_reset()` (https://raw.githubusercontent.com/torvalds/linux/v7.2/sound/soc/codecs/wcd938x.c
lines 3206-3262) — no reset-framework provider needed. This is exactly the asymmetry observed.

Why the Yoga matches: same amp driver, same `reset-gpios`, mics on VA DMICs (no wcd938x at all —
audio-routing uses only `WSA*` and `VA DMIC*`/`vdd-micb`), so "mic works, speakers silent".

### 6c. Commits between v6.16 and v7.2 on the named files (one line each)

`drivers/soundwire/qcom.c` (https://github.com/torvalds/linux/commits/v7.2/drivers/soundwire/qcom.c):
- `834bce6a715a` 2025-07-15 Revert "soundwire: qcom: Add set_channel_map api support"
- `88f5d2a477ec` 2025-09-01 soundwire: Use min() to improve code
- `6504fe8cd21f` 2025-12-08 soundwire: qcom: remove unused rd_fifo_depth
- `9e53a66a2f2f` 2025-12-08 soundwire: qcom: deprecate qcom,din/out-ports ("Number of input and output ports can be dynamically read from the controller registers … Tested-by: Alexey Klimov # sm8550")
- `6ed85ea1b17b` 2025-12-08 soundwire: qcom: prepare for v3.x ("cleanup the register layout structs")
- `b2bfe0fa1f85` 2025-12-08 soundwire: qcom: adding support for v3.1.0 (x1e80100 is `qcom,soundwire-v2.0.0`)
- `82ab754d1022` 2025-12-16 soundwire: qcom: Use guard to avoid mixing cleanup and goto
- `69050f8d6d07`/`189f164e573e` 2026-02 treewide kmalloc_obj conversions
`sound/soc/codecs/wsa884x.c` (https://github.com/torvalds/linux/commits/v7.2/sound/soc/codecs/wsa884x.c):
- `bbe5e3c433a3` 2025-07-04 Remove redundant pm_runtime_mark_last_busy() calls
- `801955fd9248` 2025-10-20 use snd_kcontrol_chip()
- `120f3e6ff762` 2026-01-05 **fix codec initialisation** (jhovold; `Fixes: aa21a7d4f68a`, stable 6.5+): "the initial state of the flag was also inverted so that the codec would only be initialised and brought out of regmap cache only mode if its status first transitions to UNATTACHED" — https://github.com/torvalds/linux/commit/120f3e6ff76209ee2f62a64e5e7e9d70274df42b
`sound/soc/codecs/lpass-wsa-macro.c` (https://github.com/torvalds/linux/commits/v7.2/sound/soc/codecs/lpass-wsa-macro.c):
- `ce1a46b2d6a8` 2025-09-03 add Codev version 2.9
- `9004a450fccb` 2025-09-04 Fix speaker quality distortion (T14s, `Fixes: bb4a0f497bc1`)
- `fe0b3f564f9b`/`af9a1da6c3ae` 2025-10/11 kcontrol/dapm API conversions
- `38fc5addd2a0`, `902f497a1ff5`, `c47f28ef62cb`, `3ea1b0dbc684`, `da49a21b3fe9`, `7ec95f46759b`, `50c28498e9fd` 2025-11-20 (Jonathan Marek) path/clock rework; `3ea1b0dbc684` "fix path clock dependencies": "previously using the mix ports only would only activate the mix path clock and no audio would play"
- `56f24311fd56` 2026-08-01 Fix enum kcontrol accesses (post-7.2)
`sound/soc/qcom/sdw.c`: `bcba17279327` 2025-10-29 fix memory leak for sdw_stream_runtime; `d02460317ed9` remove redundant code; `8fdb030fe283` sc7280 helpers.
`sound/soc/qcom/x1e80100.c`: `5ab26b8ca564` 2025-09-03 set card driver name from match data; `8c7ea98650e6` glymur compatible; `0a5ee0e520ef` 2026-04-22 limit speaker volumes.
None of these touch reset/SD_N handling or enumeration; the v3.x SoundWire series was tested on
sm8550 (same v2.0.0 controller family). No 7.x regression report for amp enumeration on x1e80100
was found (UNVERIFIED beyond search); the only silent-speaker report with Attached amps is
Ubuntu bug 2130536 (6.17, "Bus clash detected" on `sdw:1:0:0217:0204:00:0` and `sdw:4:…`, PCM
RUNNING, no sound; jhovold: "this is not a mainline issue. IIUC, Ubuntu disables audio by default
until you pass a kernel parameter") https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2130536 —
a different signature (amps enumerated, bus clash) from the G1q's (amps never enumerated).
GitHub issue search `repo:jhovold/linux wsa884x`: 0 results.

### 6d. Internal microphones on the OmniBook/G1q

`x1-hp-omnibook-x14.dtsi` sound node: `va-dai-link` "VA Capture" `<&q6apmbedai VA_CODEC_DMA_TX_0>` →
`<&lpass_vamacro 0>`; `&lpass_vamacro { pinctrl-0 = <&dmic01_default>, <&dmic23_default>;
vdd-micb-supply = <&vreg_l1b_1p8>; qcom,dmic-sample-rate = <4800000>; }`; routing
`"VA DMIC0", "MIC BIAS3"`, `"VA DMIC1", "MIC BIAS3"`, `"VA DMIC2", "MIC BIAS1"`, `"VA DMIC3", "MIC BIAS1"`,
plus `"VA DMIC0", "VA MIC BIAS3"` etc. The only wcd938x AMIC is `"AMIC2", "MIC BIAS2"` (headset).
UCM "Mic" device = `va-macro/DMIC0EnableSeq.conf` + `DMIC1EnableSeq.conf`, `CapturePCM "hw:${CardId},3"`
(https://raw.githubusercontent.com/alsa-project/alsa-ucm-conf/master/ucm2/Qualcomm/x1e80100/T14s-HiFi.conf).
So: internal mics are VA-macro DMICs; their bias is routed through wcd938x `MIC BIAS1/3` widgets (DAPM
will power them via the Attached wcd938x). The G1q's zero-peak capture is **not** the amp fault and
**not** explained by the wcd938x being unattached (it is attached). Separate fault, open.

## Q7. `adsp_dtbs.elf` variants

- Loader: `qcom_q6v5_pas.c` at v7.2 requests `dtb_firmware_name` (second `firmware-name` entry),
  loads it with `qcom_mdt_pas_load` and authenticates via `qcom_scm_pas_prepare_and_auth_reset`,
  logging "failed to authenticate dtb image and release reset" on failure — a wrong or corrupt DTB
  fails **loudly** at ADSP start, it does not produce a running ADSP.
  https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/remoteproc/qcom_q6v5_pas.c
- Extractor behaviour (Debian `qcom-firmware-extract(8)`): copies "the newest matching" of
  `adsp_dtbs.elf, adspr.jsn, adsps.jsn, adspua.jsn, battmgr.jsn, cdsp_dtbs.elf, cdspr.jsn,
  qcadsp8380.mbn, qccdsp8380.mbn, qcdxkmsuc8380.mbn, qcdxkmsucpurwa.mbn` into
  `/lib/firmware/updates/qcom/<device_path>` — the same "newest wins" rule the Yoga tester found wrong
  for `cdsp_dtbs.elf`. https://manpages.debian.org/testing/qcom-firmware-extract/qcom-firmware-extract.8.en.html
- linux-firmware WHENCE ships per-laptop ADSP sets: `qcom/x1e80100/LENOVO/21N1/{qcadsp8380.mbn,adsp_dtbs.elf,adspr.jsn,adsps.jsn,adspua.jsn,cdsp_dtbs.elf,qccdsp8380.mbn,cdspr.jsn,battmgr.jsn}`
  (lines 6929-6943), `qcom/x1e80100/LENOVO/83ED/{adsp_dtbs.elf,adspr.jsn,adsps.jsn,adspua.jsn,battmgr.jsn,cdspr.jsn,qcadsp8380.mbn,qccdsp8380.mbn,…}`
  (lines 6946-6958), `qcom/x1e80100/dell/xps13-9345/{adsp_dtbs.elf,cdsp_dtbs.elf,…}` (7101-7107),
  and generic `qcom/x1e80100/adsp.mbn`, `adsp_dtb.mbn`, `cdsp.mbn`, `cdsp_dtb.mbn` (CRD). **No `hp/`
  ADSP files.** https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/WHENCE
  Arch's `linux-firmware-qcom` file list includes `qcom/x1e80100/LENOVO/83ED/adsp_dtbs.elf.zst`,
  `qcadsp8380.mbn.zst`, `qccdsp8380.mbn.zst` (no `cdsp_dtbs.elf` for 83ED)
  https://archlinux.org/packages/core/any/linux-firmware-qcom/files/ (ALARM's 20260810-2 is the same
  source; its exact file list UNVERIFIED). Notably the Yoga's DT `firmware-name` points at
  `qcom/x1e80100/LENOVO/83ED/…`, so the packaged files would be used unless `/updates/` overrides them.
- Content: Qualcomm's DTE describes these as "NonHLOS device tree blob elf files" editable "for
  Qualcomm platforms" (https://github.com/qualcomm/DTE); whether the ADSP DTB describes the SoundWire
  amps is UNVERIFIED — no public documentation found. SoundWire enumeration itself is done by the AP
  (`drivers/soundwire/qcom.c`) and does not involve the ADSP; the WSA macro's clocks do come from the
  ADSP (`clocks = <&q6prmcc LPASS_CLK_ID_WSA_CORE_TX_MCLK …>` in `hamoa.dtsi`), so a broken ADSP audio
  image could stall the macro, but that would show as clock errors, not as silent enumeration.
- Evidence that a mismatched `adsp_dtbs.elf` yields "ADSP running, card registers, no sound": **none
  found** (UNVERIFIED). The Yoga cdsp case is the only documented variant mix-up (pr-audio-remarks).

## Q8 (retargeted). Other documented causes of "RUNNING but silent" on X1E/WSA884x

Primary-source symptom matches only:
1. **Shared SD_N via reset framework** — the reason `reset-gpios` exists for WSA8845 pairs: "Converting
   the property with shutdown GPIO to "reset-gpios" allows bringing all speakers out of reset"
   (x1e80100-crd series, https://lkml.iu.edu/hypermail/linux/kernel/2402.3/03932.html). Without a
   provider the amps are never brought out of reset (Q6b).
2. **`lpass-wsa-macro` path clocks** (`3ea1b0dbc684`, in v7.2): "previously using the mix ports only
   would only activate the mix path clock and no audio would play" — fixed before 7.2, so not this
   kernel's fault, but it is a documented no-audio mode of this macro.
   https://github.com/torvalds/linux/commit/3ea1b0dbc684
3. **`wsa884x` init flag inversion** (`120f3e6ff762`, in v7.2, stable 6.5+): codec initialised only
   after an UNATTACHED→ATTACHED transition — fixed in 7.2.
4. **SoundWire bus clash with amps Attached** (Ubuntu 6.17, Yoga Slim 7x): PCM RUNNING, "Bus clash
   detected" ×4, no sound, unresolved, told to report to distro.
   https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2130536
5. **Topology mismatch** shows as `ASoC: no backend DAIs enabled for MultiMedia1 Playback` and
   EINVAL/EIO on open (Dell XPS 13 9345, Ubuntu 25.10), i.e. errors, not clean RUNNING.
   https://discourse.ubuntu.com/t/dell-xps-13-9345-x1e80100-audio-stack-investigation-on-ubuntu-25-10/73248
6. **Missing `ucm2/codecs/wsa884x`** in an old alsa-ucm-conf package (Ubuntu, OmniBook) — silent until
   the codec dir was synced (https://bugs.launchpad.net/ubuntu-concept/+bug/2084960). Arch 1.2.16.1
   ships it, so not applicable.
7. **Volume caps**: v7.2 limits PA to 6 and digital to 81 (Q5) — quieter, not silent.
Supplies (`vdd-1p8`, `vdd-io`) and pinctrl are present in the DT and reported enabled on the G1q
(coordinator); `qcom,dmic-sample-rate` only affects VA DMIC capture.

---

## Ranked hypotheses for the next hardware session

**H1 — `CONFIG_RESET_GPIO` unset ⇒ WSA8845 SD_N never deasserted ⇒ amps UNATTACHED.** (Highest; verified in
source, see Q0; explains G1q + Yoga, the wcd938x asymmetry, clean card registration, SWR CMD errors, and the
UNATTACHED part `0204` on `6b10000`. Every other distro with working X1E speakers has `RESET_GPIO=m`.)
Read-only checks:
```sh
zcat /proc/config.gz | grep -E 'CONFIG_RESET_GPIO\b'        # expect: "# CONFIG_RESET_GPIO is not set"
modinfo reset-gpio 2>&1 | head -1                             # expect: "modinfo: ERROR: Module reset-gpio not found"
ls /sys/bus/auxiliary/devices/ 2>/dev/null | grep -i reset    # expect: nothing (Fedora would show reset_gpio.* devices)
grep -A24 '6e80000.pinctrl' /sys/kernel/debug/gpio | grep -E 'gpio-?12\b|gpio-?13\b'   # expect: no consumer label, "out lo"
for d in /sys/bus/soundwire/devices/sdw:*:0217:0204:*; do printf '%s %s\n' "$d" "$(cat $d/status 2>/dev/null)"; done
```
Meaning: `not set` + no `reset-gpio` module + LPI gpio12 unclaimed/low ⇒ confirmed; the amps cannot be
enabled by this kernel build, and no firmware/UCM change will help. If instead `CONFIG_RESET_GPIO=y/m`
and an `reset_gpio.N` auxiliary device exists ⇒ refuted, go to H2.

**H2 — SoundWire link/frame-gen failure on `swr0` independent of SD_N** (only if H1 refuted).
```sh
dmesg | grep -E '6b10000|frame gen|link status|SWR CMD|Bus clash|enumerat' | head -40
```
Meaning: `link status not connected`/`frame gen` errors ⇒ controller-side; only `SWR CMD error` bursts
with no link errors ⇒ slaves absent (consistent with H1).

**H3 — UCM `PA Volume 12` on a 0..6 control.** Not a silence cause; document the clamp:
```sh
alsaucm -c hw:0 set _verb HiFi set _enadev Speaker >/dev/null 2>&1; amixer -c0 cget name='SpkrLeft PA Volume'
```
Meaning: value 6 ⇒ alsa-lib clamped as the source says; value 1 ⇒ the cached regmap default is being
read back because the amp is UNATTACHED (supports H1). Either way, worth an upstream alsa-ucm-conf note.

**H4 — G1q internal mics: a separate fault (VA DMIC / wcd938x MIC BIAS path), not the amps.**
```sh
amixer -c0 contents | grep -iE -A2 "DMIC|MIC BIAS|VA_DEC|VA DEC|TX DMIC" | head -60
arecord -D hw:0,3 -f S16_LE -r 48000 -c 2 -d 3 /tmp/va.wav && sox /tmp/va.wav -n stat 2>&1 | grep -i 'maximum amp'
```
Meaning: non-zero peak on `hw:0,3` with DMIC0/1 muxes set ⇒ mic hardware fine, PipeWire/UCM routing;
zero even with `VA DEC0 MUX`=SWR_MIC/DMIC ⇒ bias/pin issue, compare against the Yoga (works).

**H5 — Yoga `adsp_dtbs.elf` variant mismatch.** Cheap and decisive on the Yoga only:
```sh
sha256sum /usr/lib/firmware/updates/qcom/x1e80100/LENOVO/83ED/adsp_dtbs.elf
zstdcat /usr/lib/firmware/qcom/x1e80100/LENOVO/83ED/adsp_dtbs.elf.zst | sha256sum
```
Meaning: equal ⇒ the extracted variant is the one linux-firmware ships, hypothesis dead; different ⇒
try the packaged one (remove the `/updates/` override) — but note H1 would still silence the amps.

**H6 — `tqftpserv`/QRTR daemons missing.** Lowest: no primary source ties them to WSA playback, and the
audio PD came up. Check only that the in-kernel mapper is bound:
```sh
lsmod | grep -E 'qcom_pd_mapper|qcom_pdr|qrtr'; dmesg | grep -iE 'pd-mapper|qcom_pdm|pdr' | head
```
Meaning: `qcom_pd_mapper` loaded and no PDR errors ⇒ nothing for a userspace daemon to add here.
