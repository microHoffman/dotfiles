# Anonymized Fedora laptop hibernation record

This case study preserves the useful implementation decisions without
publishing disk UUIDs, boot IDs, swap offsets, hostnames, network identifiers,
raw logs, process lists, or unrelated machine-security settings.

## Outcome

The laptop was conditionally compatible with hibernation. The storage and
resume path was configured, and three controlled direct tests genuinely
restored the old kernel and desktop session. A separately approved lid policy
was then enabled, and a human-in-the-loop battery-powered physical lid test
restored the original session.

`disk` was present in `/sys/power/state` before configuration. That proved
kernel capability only; resume was not configured at that point.

## Audited platform

- Fedora Workstation with a recent kernel
- systemd 259
- dracut 108
- UEFI boot
- Secure Boot disabled
- Approximately 32 GiB RAM
- `/sys/power/state`: `freeze mem disk`
- `/sys/power/disk`: ACPI platform hibernation selected
- s2idle was the only suspend-to-RAM mode
- LUKS2-encrypted, single-device Btrfs root
- Separate Btrfs root and home subvolumes
- No LVM
- Hybrid integrated/discrete graphics

Before setup, the only swap was an 8 GiB zram device. There was no
`HibernateLocation` UEFI variable, no resume kernel parameter, no dracut
`resume` module, and systemd did not report hibernation as available.

## Storage decision

The encrypted Btrfs filesystem initially lacked enough free space for the
recommended swap file. The partition, LUKS mapping, and Btrfs filesystem were
expanded only after:

- confirming contiguous unallocated space;
- backing up the GPT and LUKS header;
- checking storage health and Btrfs error counters;
- receiving explicit approval for the exact partition target.

Never reuse the old geometry on another machine. Recalculate all sector
boundaries from that machine's current partition table.

After expansion, a 31 GiB swap file was created inside LUKS. This protects the
hibernation image at rest and requires the normal LUKS passphrase during
power-on.

## Changes made

1. Backed up GPT, the LUKS2 header, fstab, crypttab, GRUB/BLS state, kernel
   command line, and current initramfs outside the Git repository.
2. Expanded the partition, LUKS mapping, and Btrfs only after separate approval.
3. Removed an obsolete kernel from an older Fedora release to free `/boot`
   while retaining a current fallback kernel and rescue image.
4. Updated the installed systemd package family from official Fedora
   repositories and confirmed dracut was current.
5. Created a dedicated `/var/swap` Btrfs subvolume with No_COW.
6. Created `/var/swap/swapfile`, 31 GiB, mode 0600.
7. Added `/var/swap/swapfile none swap defaults 0 0` to `/etc/fstab`.
8. Added `add_dracutmodules+=" resume "` to
   `/etc/dracut.conf.d/resume.conf`.
9. Rebuilt the running kernel's initramfs and verified that it contained:
   - Btrfs support;
   - cryptsetup and the audited crypttab;
   - the dracut resume module;
   - `systemd-hibernate-resume-generator`;
   - `systemd-hibernate-resume`.

No fixed `resume=` or `resume_offset=` kernel parameters were added. On this
UEFI/systemd version, systemd records the current swap location in the
`HibernateLocation` variable when hibernation starts.

## Swap priorities

```text
NAME               TYPE      SIZE PRIO
/dev/zram0         partition   8G  100
/var/swap/swapfile file       31G   -1
```

The Btrfs resume offset was validated but was deliberately not copied into this
public record or hard-coded into boot configuration.

## Graphics

The tested boot used the open-source drivers for the active GPUs. Proprietary
discrete-GPU packages were installed but blacklisted. Their sleep services used
conditions that safely skipped them while the proprietary driver was inactive.

If GPU drivers change, re-audit the vendor's current Fedora hibernation
requirements and repeat direct tests.

## First direct test

- Result: accepted pass with one recovered peripheral warning
- Approximate hibernation-entry time: 15 seconds
- Approximate resume time after LUKS unlock: 6 seconds
- Original windows, terminals, editors, and processes appeared restored
- Boot ID and sentinel PID were identical before and after
- Both swap devices remained active
- The journal showed genuine ACPI S4 hibernation entry and exit
- `HibernateLocation` was consumed and removed during resume

The wireless driver logged one PCI restore timeout, immediately reloaded its
firmware, and NetworkManager restored Wi-Fi within a few seconds. Later tests
must establish whether this warning recurs or affects reliability.

## Second direct test

- Result: functional pass with recovered peripheral warnings
- Approximate hibernation-entry time: 36 seconds
- Approximate resume time after LUKS unlock: 11 seconds
- Original windows, terminals, editors, and processes appeared restored
- Boot ID and sentinel PID were preserved
- Both swap devices remained active
- systemd still reported hibernation support and no units remained failed

The wireless restore timeout repeated, followed by automatic firmware reload
and successful reconnection. Bluetooth also logged transient disconnect/setup
errors, then recovered and reconnected the paired headset. These warnings must
remain visible in the final reliability assessment even though the user-facing
session and radios recovered.

## Third direct test

- Result: functional pass with the same recovered peripheral warnings
- Hibernation and resume timings were approximately the same as test 2
- Representative terminals and editors were open
- Recognizable, non-important unsaved test text was restored
- Boot ID and sentinel PID were preserved
- The user-facing session and processes were restored

The same wireless and Bluetooth warnings repeated and recovered. Across all
three tests, the hibernation image and user session restored successfully; the
radio-driver resume path was consistently noisy but self-recovering.

## Physical lid test

- Power source: battery
- External displays or dock: none
- Approximate hibernation-entry time: 45 seconds
- Approximate resume time after LUKS unlock: 15 seconds
- logind recorded the lid closure and selected hibernation
- Boot ID and sentinel PID were preserved
- Windows, terminals, editors, and processes were restored
- Wi-Fi recovered and reconnected automatically
- Bluetooth recovered and remained powered
- No system units remained failed

The automated result was a warning because the same MediaTek wireless restore
timeout and transient Bluetooth errors recurred. They recovered as in all three
direct tests, so the physical test was accepted with that known limitation.

## Remaining considerations

- Monitor any peripheral restore warnings.
- Re-test after significant kernel, firmware, systemd, or GPU-driver changes.
- The battery lid trigger was physically tested; external-power and docked
  policy branches were configuration-verified but not physically exercised.
- Check `/boot` capacity before installing additional kernels.
- Disable the swap file before Btrfs operations that need to relocate its
  pinned extents.
- Keep raw recovery backups and test evidence outside public Git.

## Lid behavior

After three accepted direct tests, the active owner and policy were audited:

- systemd-logind owned the lid action;
- the compositor had no active lid binding;
- no inhibitor took over the handle-lid-switch action;
- battery lid close was set to hibernate;
- external-power lid close was set to hibernate;
- docked or external-display lid close was set to ignore.

Restarting systemd-logind to activate the policy terminated the active
Hyprland graphical session. A subsequent normal boot was healthy and loaded
the intended policy. On this system logind reports `CanReload=yes`, so the
saved procedure uses `systemctl reload systemd-logind`; if reload is
unavailable, activation should wait for a planned reboot.

The battery policy passed a physical test after saving work, outside a bag on
a hard surface. The machine reached S4 and restored the original session.

Hibernation does not make accidental power-on impossible. Firmware can still
permit S4/S5 power-on through RTC, network, USB, PCIe, or vendor-specific
sources.
