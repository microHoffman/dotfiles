# Fedora workstation hibernation

This directory records the hibernation setup used on the local Fedora laptop.
It is both a recovery reference and a starting point if hibernation needs to be
configured again.

It is not a blind installer. Disk geometry, encryption, filesystems, RAM,
firmware, GPU drivers, systemd, and dracut must be audited on the target machine
before making persistent changes. In particular, never replay partition-resize
commands from an old machine.

An anonymized record of the implementation is
[`records/example-fedora-laptop.md`](records/example-fedora-laptop.md).

## Current live configuration

The live system uses:

- an 8 GiB zram swap device at priority 100;
- a 31 GiB disk-backed swap file at `/var/swap/swapfile`, priority -1;
- a dedicated No_COW Btrfs subvolume at `/var/swap`;
- an `/etc/fstab` entry matching [`config/fstab.swap`](config/fstab.swap);
- `/etc/dracut.conf.d/resume.conf` matching
  [`config/resume.conf`](config/resume.conf);
- `/etc/systemd/logind.conf.d/50-hibernate-on-lid.conf` matching
  [`config/logind-hibernate-lid.conf`](config/logind-hibernate-lid.conf);
- systemd's UEFI `HibernateLocation` mechanism, without fixed `resume=` or
  `resume_offset=` kernel parameters.

The swap file is inside the LUKS2-encrypted root volume. The normal LUKS
passphrase is therefore required during power-on before the image can resume.
Three direct tests and one battery-powered physical lid test restored the
original kernel and desktop session.

Run the read-only verification:

```bash
sudo setup/fedora-hibernation/verify.sh
```

The verifier does not suspend, hibernate, reboot, or modify configuration.

## Reproducing the setup

### 1. Audit first

At minimum, inspect:

```bash
cat /etc/fedora-release
uname -r
systemctl --version
dracut --version
test -d /sys/firmware/efi && echo UEFI
mokutil --sb-state
cat /sys/kernel/security/lockdown
grep MemTotal /proc/meminfo
df -h / /boot /boot/efi
lsblk -e7 -o NAME,PATH,TYPE,SIZE,FSTYPE,FSVER,MOUNTPOINTS
findmnt /
cryptsetup status "$(findmnt -no SOURCE / | sed 's/\[.*//; s#^/dev/mapper/##')"
swapon --show
cat /etc/fstab
cat /sys/power/state
cat /sys/power/disk
cat /sys/power/mem_sleep
busctl call org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager CanHibernate
lspci -nnk
systemd-inhibit --list
```

`disk` in `/sys/power/state` proves that the kernel has hibernation support. It
does not prove that swap, initramfs resume support, or the boot-time resume path
is configured.

Check the current initramfs rather than assuming Fedora defaults:

```bash
sudo lsinitrd -m "/boot/initramfs-$(uname -r).img"
sudo lsinitrd "/boot/initramfs-$(uname -r).img" |
  grep -Ei 'resume|hibernate|cryptsetup|btrfs'
```

Also inspect the boot loader, available `/boot` space, Btrfs error counters,
NVMe health, firmware wake sources, and the active GPU driver.

### 2. Size disk-backed swap

Use current Fedora guidance and the target machine's actual RAM. The audited
laptop has 30.5 GiB RAM and uses a 31 GiB swap file. Its configured kernel image
size is approximately 12.1 GiB:

```bash
cat /sys/power/image_size
```

Keep zram unless an actual incompatibility is demonstrated. Hibernation uses
the disk-backed swap while zram continues to serve normal runtime swapping.

### 3. Create a Btrfs swap file

These commands are a reference for a compatible single-device Btrfs filesystem.
Re-audit before running them:

```bash
sudo btrfs subvolume create /var/swap
sudo chattr +C /var/swap
sudo mkswap --file --label SWAPFILE --size 31G /var/swap/swapfile
sudo chmod 0600 /var/swap/swapfile
sudo btrfs inspect-internal map-swapfile -r /var/swap/swapfile
```

`mkswap --file` from util-linux 2.41 prepares a suitable No_COW swap file.
`btrfs inspect-internal map-swapfile` must succeed before enabling it.

Add the exact line from [`config/fstab.swap`](config/fstab.swap) to
`/etc/fstab`, then validate and activate it:

```bash
sudo findmnt --verify --verbose
sudo systemctl daemon-reload
sudo swapon /var/swap/swapfile
swapon --show
```

The regular-file warning from `findmnt --verify` is expected for a swap file;
parse errors or other errors are not.

### 4. Add boot-time resume support

Install [`config/resume.conf`](config/resume.conf) as
`/etc/dracut.conf.d/resume.conf`, then rebuild the running kernel's initramfs:

```bash
sudo install -o root -g root -m 0644 \
  setup/fedora-hibernation/config/resume.conf \
  /etc/dracut.conf.d/resume.conf
sudo dracut --force "/boot/initramfs-$(uname -r).img" "$(uname -r)"
sudo lsinitrd -m "/boot/initramfs-$(uname -r).img" | grep -x resume
```

On the audited UEFI system with systemd 259, systemd writes the selected swap
device and Btrfs offset to the UEFI `HibernateLocation` variable when
hibernation starts. The initramfs consumes that variable after LUKS is unlocked.
No fixed resume parameters were added to the BLS entries.

### 5. Test direct hibernation

Do not configure the lid until direct hibernation is repeatable. Use the
controlled test tool:

```bash
sudo setup/fedora-hibernation/tests/direct-hibernate-test.sh prepare 1
sudo setup/fedora-hibernation/tests/direct-hibernate-test.sh \
  hibernate 1 --i-saved-my-work

# After power-on, LUKS unlock, and resume:
sudo setup/fedora-hibernation/tests/direct-hibernate-test.sh check 1
```

Repeat with test numbers 2 and 3. Test 3 should include representative
terminals and editors with recognizable, non-important unsaved test text.

For every round, record:

- time from the command until the machine is fully powered off;
- time from LUKS unlock until the restored desktop is usable;
- whether the same windows, terminals, editors, and processes returned;
- boot-ID and sentinel preservation;
- hibernation/resume warnings and errors.

Stop after any failure and diagnose it before another test. Lid-close behavior
must remain unconfigured until all direct tests are accepted.

## Kernel updates

The dracut drop-in applies to initramfs images generated for future kernels, so
normal kernel updates do not require new fstab entries, new resume offsets, or
new kernel parameters.

One rule is essential: after installing a kernel, reboot into it before
hibernating. Do not create an image with the old running kernel when the boot
loader is set to start a newly installed kernel.

After rebooting into a new kernel:

```bash
sudo lsinitrd -m "/boot/initramfs-$(uname -r).img" | grep -x resume
swapon --show
busctl call org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager CanHibernate
```

Repeat at least one direct test after a significant kernel, systemd, firmware,
or GPU-driver change.

## Maintenance constraints

An active Btrfs swap file pins its extents and block group. Disable it before
Btrfs maintenance that needs to relocate those extents:

```bash
sudo swapoff /var/swap/swapfile
# Perform the audited maintenance.
sudo swapon /var/swap/swapfile
```

Never delete, recreate, copy, defragment, or move the swap file while it is
active. Recreating it changes its physical resume location; validate it again
before the next hibernation.

## Lid-close behavior

The recorded policy was enabled only after three accepted direct-hibernation
tests:

- battery: hibernate;
- external power: hibernate;
- docked or using external displays: ignore.

systemd-logind owns the lid action on the audited Hyprland system. The
compositor has no active lid binding, and no inhibitor takes over the
handle-lid-switch action. Install the drop-in with:

```bash
sudo install -d -o root -g root -m 0755 /etc/systemd/logind.conf.d
sudo install -o root -g root -m 0644 \
  setup/fedora-hibernation/config/logind-hibernate-lid.conf \
  /etc/systemd/logind.conf.d/50-hibernate-on-lid.conf
systemctl show systemd-logind --property=CanReload
sudo systemctl reload systemd-logind
```

Use `reload` only when `CanReload=yes`. Restarting logind terminated the
graphical session on the audited Hyprland machine, so do not use `restart` from
an active desktop. If reload is unavailable, leave the file installed and
activate it during the next planned reboot after saving work.

Reloading the policy does not itself suspend or hibernate. Test the actual lid
trigger separately, after saving work, outside a bag on a hard surface.
Confirm full power-off and successful restoration before relying on it for
transport.

The recorded laptop passed this physical battery test: logind recorded the lid
closure and selected hibernation, the same boot ID and sentinel process
returned, and the user session was restored. Entry took approximately 45
seconds and the desktop was usable approximately 15 seconds after LUKS unlock.
The same recoverable wireless and Bluetooth driver warnings seen in direct
testing remained.

Hibernation does not make accidental power-on impossible. Firmware can still
permit S4/S5 wake or power-on through RTC alarms, Wake-on-LAN, USB, PCIe, or
vendor-specific sources.

## Rollback

Preview the rollback:

```bash
sudo setup/fedora-hibernation/rollback.sh
```

Apply it only after reading the preview and saving work:

```bash
sudo setup/fedora-hibernation/rollback.sh --apply
```

The rollback removes the swap/resume configuration and rebuilds the running
kernel's initramfs. It deliberately does not shrink partitions, LUKS, or Btrfs,
and does not downgrade packages or reinstall old kernels.

## Backup policy

Do not commit raw recovery material or test captures:

- LUKS header and GPT backups;
- initramfs images;
- the swap file;
- full journals and process listings;
- credentials or secrets.

Keep the LUKS header backup root-only and copy it to separately encrypted,
offline storage. A suitable local backup location is
`/var/backups/hibernate-setup-<timestamp>`.

## References

- [Fedora Workstation hibernation update](https://fedoramagazine.org/update-on-hibernation-in-fedora-workstation/)
- [systemd-hibernate-resume-generator](https://www.freedesktop.org/software/systemd/man/latest/systemd-hibernate-resume-generator.html)
- [systemd-hibernate-resume](https://www.freedesktop.org/software/systemd/man/latest/systemd-hibernate-resume.html)
- [Linux swsusp documentation](https://docs.kernel.org/power/swsusp.html)
- [Btrfs swapfile documentation](https://btrfs.readthedocs.io/en/latest/Swapfile.html)
- [RPM Fusion NVIDIA guidance](https://rpmfusion.org/Howto/NVIDIA)
