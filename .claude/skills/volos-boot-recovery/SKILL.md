---
name: volos-boot-recovery
description: Recover the volos RPi5 step-ca host when it won't boot — typically after a power-cut following `colmena apply` leaves a stale/partial boot generation. Use when volos fails at NixOS stage 2 ("init script not found"), sits at the red "Trying boot mode SD" firmware screen, or otherwise won't reach a login. Boots a NixOS SD, chroots into the ZFS pool, and reinstalls the bootloader.
---

# volos boot recovery

`volos` = Raspberry Pi 5 + NVMe, the step-ca certificate authority (`machine-specific/tinyca`,
hostId `c3adcefb`, built from the `nixos-raspberrypi` flake). ZFS `rpool` on NVMe.

## Symptom this fixes

After `colmena apply --on volos` + a hard power-off, on next boot:

- Stage 1 imports `rpool` and mounts datasets fine, then **stage 2 dies**:
  `Stage 2 init script (/nix/store/<hash>-nixos-system-volos-25.11pre-git/init) not found`
- Firmware may show the red **`Trying boot mode SD`** screen.
- The Pi EEPROM boot-mode selector **ignores keyboard input** (JetKVM-emulated *and* real USB) — you cannot fix this from the firmware screen.

## Root cause

Power-cut raced the commit. The new generation's closure didn't commit to the ZFS txg
and/or the boot generation tree on the **FAT firmware partition** was left partial (FAT = no
journaling). The pool and generations are almost always intact — **only the boot files are
broken**, pointing at a closure that isn't on disk. Fix = regenerate boot files; do **not**
re-deploy or touch the pool data.

## CRITICAL non-obvious fact

On this `nixos-raspberrypi` image the bootloader files live on the **FIRMWARE partition**
(`/dev/nvme0n1p1` → `/boot/firmware`): `config.txt` + the `nixos/` generation tree
(kernels, initrd, dtbs). They do **NOT** live on the ESP (`/dev/nvme0n1p2` → `/boot`), which
is essentially empty — a red herring. Pi5 firmware reads `config.txt` straight off FIRMWARE.

## Partition + dataset layout (`/dev/nvme0n1`)

| Partition | FS   | Mount            |
|-----------|------|------------------|
| p1        | vfat | `/boot/firmware` (FIRMWARE — bootloader lives here) |
| p2        | vfat | `/boot` (ESP — empty) |
| p3        | zfs  | `rpool` |

Datasets use **legacy** mountpoints → mount with `mount -t zfs`, NOT `zfs mount`:
`rpool/system/root`→`/`, `rpool/local/nix`→`/nix`, `rpool/system/var`→`/var`,
`rpool/safe/var/lib`→`/var/lib`, `rpool/safe/home`→`/home`.
Verify the live set first: `zfs list -o name,mountpoint,canmount`.

## Recovery procedure

Boot a `nixos-raspberrypi` SD image (includes ZFS). SD is first in the EEPROM boot order
(`BOOT_ORDER=0xf461`), so it takes priority over NVMe. Then, as root:

### 1. Import pool + mount (root FIRST, then nested)

```bash
zpool import -f -N -R /mnt rpool      # -f: SD hostId differs from volos. -N: no auto-mount.
mount -t zfs rpool/system/root /mnt   # root first
mkdir -p /mnt/nix && mount -t zfs rpool/local/nix /mnt/nix
mount -t zfs rpool/system/var  /mnt/var      2>/dev/null || (mkdir -p /mnt/var && mount -t zfs rpool/system/var /mnt/var)
mount -t zfs rpool/safe/var/lib /mnt/var/lib 2>/dev/null || (mkdir -p /mnt/var/lib && mount -t zfs rpool/safe/var/lib /mnt/var/lib)
mount -t zfs rpool/safe/home   /mnt/home     2>/dev/null || (mkdir -p /mnt/home && mount -t zfs rpool/safe/home /mnt/home)
mount /dev/nvme0n1p2 /mnt/boot          # ESP
mount /dev/nvme0n1p1 /mnt/boot/firmware # FIRMWARE (where boot files actually live)
mount | grep /mnt                       # sanity check
```

### 2. Confirm the pool is healthy (don't trust JetKVM-typed hashes)

```bash
zpool status -v rpool                          # want ONLINE, no data errors
ls /mnt/nix/store/ | grep nixos-system-volos   # the volos system closures present
ls -la /mnt/nix/var/nix/profiles/ | grep system  # which generation is current
```

JetKVM mangles `*` (becomes a literal `x`) and drops characters from pasted hashes — a
hand-typed `ls /nix/store/<hash>*` will give false "No such file" results. Use `grep` on a
plain directory listing instead. ONLINE pool + non-trivial `ls /nix/store | wc -l` = pool fine.

### 3. Enter and reinstall the bootloader

Do a **clean** mount first (step 1). A half-mounted prior attempt makes `nixos-enter` abort
with `install: cannot create directory '/mnt/etc/static': File exists`.

```bash
nixos-enter --root /mnt
# inside the chroot (prompt hostname stays "nixos-installer" — that's cosmetic; `cat /etc/hostname` says volos):
/nix/var/nix/profiles/system/bin/switch-to-configuration boot
```

This rewrites the `nixos/` generation tree on `/boot/firmware` against the current profile
generation. It prints `generational bootloader installed`. Confirm fresh timestamps:

```bash
ls -la /boot/firmware/nixos
ls -la /boot/firmware            # config.txt should be freshly dated
exit
```

To boot an **older** generation instead (if the current one is genuinely broken on disk),
roll the profile back before switch-to-configuration:
`nix-env -p /nix/var/nix/profiles/system --switch-generation <N>` then run
`/nix/var/nix/profiles/system/bin/switch-to-configuration boot`.

### 4. Teardown + reboot

```bash
cd /
umount /mnt/boot/firmware; umount /mnt/boot
umount /mnt/home 2>/dev/null; umount /mnt/var/lib 2>/dev/null; umount /mnt/var 2>/dev/null
umount /mnt/nix; umount /mnt
mount | grep /mnt        # want empty
zpool export rpool       # clean export so volos imports fresh
```

Power off, **pull the SD card** (else firmware boots SD again — it's first in BOOT_ORDER),
power on. Firmware falls through to NVMe and reads the fresh `/boot/firmware/config.txt`.

## Verify recovery

```bash
systemctl status step-ca --no-pager
journalctl -u step-ca -b --no-pager | tail -30
zpool status rpool
```

## Prevention

The incident only happened because `colmena apply` + an immediate hard power-off raced the
commit. After any apply to volos:

```bash
ssh volos 'sync && zpool sync rpool'   # before powering down
```

Prefer `systemctl poweroff` over a hard power-cut.

## Notes

- step-ca data lives on `safe/*` datasets and is never at risk in this procedure — it's a
  boot-files problem, not a data problem.
- Per repo convention, do not run live cluster mutations yourself — hand commands to the user
  to run on the box / from their workstation.
