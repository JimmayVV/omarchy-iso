# Evidence

Photos and captures from real-hardware sessions on the Omarchy-on-Snapdragon map
(https://github.com/JimmayVV/omarchy-iso/issues/1). Kept on their own branch so
the code branches carry no binaries; referenced from the tickets and, later, the
upstream PR.

## HP EliteBook Ultra G1q (Snapdragon X1E-78-100)

- `g1q/2026-08-26-omarchy-desktop.jpg` — first Omarchy desktop on the machine.
  Stock Arch Linux ARM `linux-aarch64` 7.2, Limine → UKI with `.dtbauto`, GPU zap
  shader and DSP firmware copied from the owner's Windows partition by
  `qcom-firmware-extract` during the install. Root on an external NVMe (USB-A).
- `g1q/2026-08-26-usbc-root-drop.jpg` — the same install with the drive on a USB-C
  port: `cdsp` boots from the extracted firmware at 10.8 s, the Type-C port
  controller resets the port, `sda` I/O errors, btrfs forced read-only (#27).
