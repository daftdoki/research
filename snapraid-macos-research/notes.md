# Research Notes: SnapRAID-like Functionality on macOS Apple Silicon

## Goal

Investigate solutions on modern macOS (Apple Silicon, M-series) that provide:
1. **Independent filesystems per disk** — losing one drive does not lose data on the others.
2. **Per-drive spin-down** — drives can sleep individually when idle.
3. **Parity-based protection** against drive failure.

Plus: management/setup tools, GUIs, helper utilities, and community guides.

---

## Round 1: SnapRAID itself

### Homebrew status (excellent)
- `brew install snapraid` — version **14.4** as of search.
- Bottles (precompiled binaries) for **arm64_tahoe**, **arm64_sequoia**, **arm64_sonoma** all available.
- No Apple-Silicon-specific build issues.
- Homebrew on Apple Silicon installs to `/opt/homebrew` (vs `/usr/local` on Intel).

### How SnapRAID works (from snapraid.it/faq)
- **Snapshot-based**, not real-time — parity is updated only when you run `snapraid sync`.
- Each data disk holds a **regular, independent filesystem**. Files on each disk are readable on their own without SnapRAID.
- Parity is stored on dedicated parity disks (1 to 6, depending on how much redundancy you want).
- 128-bit SpookyHash checksums on every file detect silent corruption (bitrot).
- Can recover data on **non-failed** disks even when redundancy limit is exceeded — this is unique vs traditional RAID.
- Only the disk(s) being read need to spin — perfect for spin-down.
- ~1 GB RAM per 16 TB of data.
- SATA strongly preferred over USB; SMART monitoring strongly recommended.

### Filesystem support per SnapRAID FAQ
- **Data disks:** ext4, XFS, NTFS preferred; Btrfs/ZFS acceptable; **HFS+ and APFS not in the recommended list but generally work** (SnapRAID just needs files with stable inode-like behavior).
- **Parity disks:** ext4 (≤16TB), XFS, Btrfs preferred; **HFS+ acceptable**; APFS not explicitly listed.
- FAT and ReFS unsupported.
- For macOS users this means: APFS works in practice (it's what most external Macs drives use today), HFS+ is well-tested.

### Key warnings
- Run memory diagnostics before initial setup (faulty RAM is the #1 cause of data loss).
- Don't use SnapRAID for high-churn data (databases, VMs, etc.).
- Files added between sync runs are unprotected if a drive fails before next sync.
- Parity disk must be ≥ size of the largest data disk.

### Comparison vs alternatives (snapraid.it/compare)
| Feature | SnapRAID | RAID/ZFS/Btrfs |
|---|---|---|
| Real-time | No (snapshot) | Yes |
| Disks readable independently | Yes | No |
| Mix of disk sizes | Yes | Limited |
| Add disks already containing data | Yes | No |
| Multi-disk failure recovery beyond parity count | Partial (non-failed disks still readable) | Total loss |
| Bitrot detection | Yes (SpookyHash 128-bit) | Yes (zfs/btrfs) or No (md/RAID) |
| Spin-down friendly | Yes | No (all disks active) |

---

## Round 2: Management & automation tools

### Elucidate (GUI for SnapRAID)
- Smurf-IV/Elucidate on GitHub — .NET WinForms app.
- **Windows-focused**. Possible to run via Mono on macOS but unlikely to work cleanly; .NET 6+ on macOS could work but the project hasn't been verified for it.
- Realistically Elucidate is **not a Mac option**.

### snapraid-runner (Chronial/snapraid-runner)
- Python 3.7+ script that runs `snapraid diff/sync/scrub` and emails results.
- Officially supports **Linux, Windows, macOS**.
- Designed for cron/Windows Scheduler. Adaptable to macOS launchd trivially.

### snapraid-aio-script (auanasgheps/snapraid-aio-script)
- Bash. Linux-focused (`bash`, `mailx`, etc.). Should work on macOS with bash and notification adjustments, but designed for OMV/Linux.
- Notable features: container management, threshold checks, Apprise/Healthchecks notifications.
- Probably runnable on macOS with effort, but no Mac documentation.

### snapper (firasdib/snapper)
- "Probably the best SnapRAID runner." Node.js-based. Cross-platform potential — no Mac-specific docs but Node runs fine on Apple Silicon.

### snapraid-btrfs / snapraid-btrfs-runner
- Linux-only because it depends on Btrfs snapshots. Not relevant to macOS.

### macOS automation: launchd
- Substitute for cron on macOS.
- LaunchAgent (`~/Library/LaunchAgents`) runs as user; LaunchDaemon (`/Library/LaunchDaemons`, root-owned) runs system-wide regardless of login.
- Use `ProgramArguments` array with full path to `/opt/homebrew/bin/snapraid`.
- Use `StartCalendarInterval` for cron-like scheduling.
- For long-running sync that should retry/log: pair with snapraid-runner or a wrapper script.

### Drive health monitoring on macOS
- **DriveDx** (BinaryFruit, paid) — comprehensive SMART analysis, supports USB drives via the SATSMARTDriver kext.
- **smartmontools** (Homebrew: `brew install smartmontools`) — open source `smartctl`/`smartd`. USB SAT pass-through often requires the SATSMARTDriver kernel extension on Apple Silicon, which has the same kext-pain as macFUSE.
- Apple Silicon SMART caveat: USB drives typically don't expose SMART; Thunderbolt drives do. Native `diskutil info` can show SMART status only for natively-supported drives.

---

## Round 3: Drive pooling / unification

### mergerfs (Linux, FUSE)
- Best-in-class Linux pooling — pairs perfectly with SnapRAID.
- **Not currently ported to macOS.** PR #384 (ahknight) attempted Mac updates years ago, never merged. The project explicitly states it's Linux-only because no maintainer for Mac/Windows.
- Re-attempting a port is non-trivial because mergerfs uses libfuse internals (`fuse_config_set_attr_timeout`, etc.) that don't exist in macFUSE/FUSE-T.

### unionfs-fuse (rpodgorny/unionfs-fuse)
- Has a maintained macOS fork: **WaterJuice/unionfs-fuse-macos** — provides universal2 (Intel + arm64) prebuilt binaries.
- Runs on macFUSE. Works on Apple Silicon, but requires the macFUSE kext (kext security pain pre-Tahoe; in macOS 26 Tahoe macFUSE has an FSKit user-space backend, no kext needed).
- Less feature-rich than mergerfs (no per-disk policies for write balancing, etc.) but sufficient as a basic union layer.
- Could provide a unified view for Plex/Jellyfin while SnapRAID protects underlying disks.

### mhddfs
- Older, Linux-mostly, semi-abandoned. Not a serious option for macOS.

### Apple's stance
- macOS doesn't ship a native union mount. Apple uses "firmlinks" for the system/data volume split, but firmlinks are not a general-purpose tool.
- No native bind-mount. No native union/overlay FS.

### macFUSE vs FUSE-T (huge for Apple Silicon)
- **macFUSE** (osxfuse successor): Kernel extension. On Apple Silicon you must boot to Recovery, lower System Security to "Reduced", allow third-party kexts, and reboot. Deal-breaker for many.
- **FUSE-T** (https://www.fuse-t.org/): User-space, no kext required — uses an internal NFS v4 local server instead. Recommended over macFUSE for Apple Silicon (e.g., VeraCrypt project recommends FUSE-T).
- **macFUSE 26+ with FSKit**: macOS Tahoe (26) introduced FSKit, a user-space filesystem framework. macFUSE now has an FSKit backend; supported file systems can run entirely in user space, no kext, no Recovery dance. (https://macfuse.github.io/)
- Practical: for unionfs on Apple Silicon, FUSE-T compatibility varies; on macOS 26+ the FSKit-backed macFUSE removes the friction.

### Implication for SnapRAID + pooling on Mac
- The clean Linux model (mergerfs union over data disks + SnapRAID parity) does not have a native equivalent on macOS.
- Workable approximations:
  1. **Skip pooling.** Mount data disks at `/Volumes/Data1`, `/Volumes/Data2`, etc. Configure Plex/Jellyfin/etc. to scan multiple library paths. Keeps things simple, native-friendly.
  2. **Use unionfs-fuse-macos** for a single mount-point view. Adds FUSE dependency.
  3. **Use symlink trees** — manually maintained or scripted (rsync/find-based) to present a unified directory of symlinks. Crude but kext-free.

---

## Round 4: Alternatives to SnapRAID on macOS

### Real-time RAID solutions
- **Apple Disk Utility "RAID Assistant"** — supports striped (RAID 0), mirrored (RAID 1), concatenated (JBOD).
  - **No RAID 5/6 / parity.** No bitrot detection.
  - Loses the "each disk independently readable" property for stripe/mirror sets.
- **SoftRAID** (https://www.softraid.com/) — commercial. Supports RAID 0/1/4/5/1+0 on macOS including Apple Silicon. Provides software parity (RAID 4/5).
  - Requires its own kext / system extension; on Apple Silicon needs Reduced Security boot mode in older macOS releases. Recent versions use endpoint security/system extensions.
  - Real-time protection. All disks active during reads/writes (not spin-down friendly).
  - Disks not independently readable on a non-SoftRAID Mac.
- **OWC SoftRAID Lite XT** — limited RAID 0/1, free with select OWC enclosures.

### OpenZFS on OS X (o3x / openzfsonosx)
- Pool version 5000 + feature flags; can import pools from Linux/FreeBSD if features overlap.
- Apple Silicon arm64 support: ports done; ZFS 2.3.0 stable on Sonoma+; 2.3.1-rc1 shows kernel panics on macOS Tahoe (26).
- Not "independent disks" model — vdev pool requires all disks for normal operation.
- **Spin-down:** ZFS continually pings disks (TXG flushes ~5 sec, ZIL sync, etc.). Spin-down with ZFS is notoriously hard. Some success with `vfs.zfs.txg.timeout` tuning, autotrim off, dataset `relatime=off`, but in practice ZFS keeps disks awake.
- ZFS gives you bitrot detection + send/receive backups + snapshots — strong CoW protection but trades off the SnapRAID "easy spin-down + independent disks" model.
- Native APFS doesn't have integrity checksumming for user data; APFS only checksums metadata. Bitrot on APFS goes undetected.

### Btrfs on macOS
- No production-quality Btrfs port for macOS. Btrfs progs run via FUSE projects but read-only and unmaintained. Effectively unavailable.

### PAR2 / Parchive
- File-level parity, designed for Usenet/file distribution.
- Can be installed via MacPorts (`port install par2`) or built from source.
- Not a drop-in SnapRAID replacement: PAR2 protects a fixed set of files at a fixed time; you must re-run par2create whenever files change.
- Reasonable for archival data that never changes; bad for active media libraries.

### ChronoSync / Carbon Copy Cloner / SuperDuper!
- Mac backup tools — these are 1:1 mirrors, not parity. Useful for off-site/secondary backups in addition to SnapRAID, not a replacement.

### rclone with checksum sidecar (manual)
- Hash-based integrity checking — not parity, no recovery.

### dwarFS / read-only archive solutions
- Can compress + checksum read-only archives. Not a fit for live media.

### Time Machine
- File-level backup, not parity. Multi-disk Time Machine (macOS Big Sur+) supports rotating backup disks. Not a SnapRAID replacement.

---

## Round 5: macOS NAS / Mac mini setups

### Mac mini as NAS (popular pattern, esp. Apple Silicon M1/M2/M4)
- M-series Mac mini idles ~5–10W; 20W with drives spun-down + idle workloads; ~48W active.
- USB4/Thunderbolt enclosures with PCIe tunneling allow JMB585-based 5-bay or larger SATA expansion. Real-world ~2800 MB/s.
- Mac mini natively serves SMB and AFP. macOS Server is gone (only Profile Manager / Open Directory left in Server.app), but file sharing is built into System Settings → General → Sharing.
- iOS/iPadOS clients can connect via Files app "Connect to Server" (smb://...).

### Power-related notes for NAS use
- `pmset -a disksleep <min>` — global disk sleep timer.
- `pmset -a sleep 0` — disable system sleep (you want this for an always-on NAS so the host doesn't sleep, but disks can still spindown individually).
- `pmset -a powernap 0`, `disable wakeOnAppleMD`, etc., to stop Apple-induced wakes.
- `caffeinate -dimsu` from Homebrew or built-in to keep Mac awake during long syncs.
- Many users report Mac mini wakes from sleep on disk events; tame with `pmset -a hibernatemode 0` and disabling power nap.

### Drive enclosures for the SnapRAID-on-Mac use case
- Single-bay USB-C enclosures (UASP, no RAID) — simplest, each drive its own filesystem (good for SnapRAID).
- Multi-bay JBOD enclosures with per-bay USB-IF mounting (e.g., OWC Mercury Elite Pro Quad in JBOD mode, Yottamaster, TerraMaster D5-300 in JBOD) — present each drive separately. **Critical:** make sure the enclosure is configured for **JBOD/Independent Disks**, NOT hardware RAID.
- Direct-attached SATA via M.2 HBA in Thunderbolt enclosure (e.g., IOCREST JMB585+JMB575 in Inateck enclosure) — best performance per dollar; treats drives as native SATA.
- DAS like OWC ThunderBay 8 in non-RAID mode are popular.

### Spin-down on multi-bay enclosures
- Many enclosures spin down idle drives in their own firmware (independent of `pmset`).
- Cheap multi-bay USB enclosures often **disconnect** drives instead of letting them sleep; this causes APFS volumes to remount or be marked as "not properly ejected." Look for enclosures explicitly advertising "independent drive sleep" via firmware.
- Forum consensus: OWC, Sabrent multi-bay, and TerraMaster D5-300 generally do per-drive spin-down well on macOS.

---

## Round 6: macOS-specific gotchas

### APFS containers and SnapRAID
- An APFS **container** can hold multiple APFS **volumes** that all share the same physical drive's free space. SnapRAID treats each volume as a path, but the underlying media is shared — that's fine, but be aware that APFS encryption, snapshots, and Time Machine local snapshots can throw off SnapRAID's picture if it sees the same underlying blocks twice.
- Best to use one APFS volume per data disk for SnapRAID. Avoid putting parity and data on the same physical disk.

### APFS snapshots
- Time Machine creates local APFS snapshots; these can hold extra space and confuse free-space estimates. They don't break SnapRAID (snapshots are invisible at the file path level), but they can fill the disk.
- Run `tmutil listlocalsnapshots /` and `tmutil deletelocalsnapshots <date>` to manage.

### case-sensitivity
- macOS APFS and HFS+ default to case-**insensitive**. Linux SnapRAID filesystems are typically case-**sensitive**. SnapRAID handles this correctly per disk (treats each disk's filesystem semantics natively), but if you ever migrate a disk between Linux and macOS, watch for collisions.

### File path stability
- SnapRAID requires stable inode numbers for incremental sync. APFS inodes are stable across reboots; HFS+ "Catalog Node IDs" are stable. Both are safe.
- **Important**: macOS `.DS_Store` files, `._AppleDouble` resource forks, `.Trashes`, `.Spotlight-V100`, `.fseventsd` — exclude these in SnapRAID config (`exclude` directives).

### APFS "Volume Group" / boot drive
- Don't include the boot volume in SnapRAID; SIP-protected paths and snapshot semantics make it pointless and risky.

---

## Round 7: Quick-look at automation specifics

### Sample launchd plist (sketch)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>com.local.snapraid.sync</string>
    <key>ProgramArguments</key>
    <array>
      <string>/usr/bin/python3</string>
      <string>/Users/me/snapraid-runner/snapraid-runner.py</string>
      <string>-c</string>
      <string>/Users/me/.snapraid/runner.conf</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key><integer>3</integer>
      <key>Minute</key><integer>30</integer>
    </dict>
    <key>StandardOutPath</key><string>/tmp/snapraid.out.log</string>
    <key>StandardErrorPath</key><string>/tmp/snapraid.err.log</string>
  </dict>
</plist>
```

Load with `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.local.snapraid.sync.plist`.

### Notification options on macOS
- `osascript -e 'display notification "..." with title "SnapRAID"'` — built-in.
- `terminal-notifier` — Homebrew, programmatic notifications.
- `Apprise` (Python) — many backend services (Pushover, Slack, Discord, etc.).
- HealthChecks.io — `curl https://hc-ping.com/<uuid>` from cron/launchd.

---

## Round 8: SnapRAID built-in features that matter for macOS

### Built-in pool command (no mergerfs needed!)
- `snapraid pool` builds a directory of symlinks unifying all data disks under one mount-point — SnapRAID's own answer to mergerfs-style pooling. Works on any OS with symlinks (so yes on macOS).
- The `pool` directive in `snapraid.conf` defines the target directory.
- Read-only via the pool: you cannot create new files in the pooled directory; new files must be written directly to a data disk. (mergerfs supports writes via policies; SnapRAID's `pool` does not.)
- Apps that scan a media library (Plex, Jellyfin, Emby) can read the pool directory transparently.
- For network sharing, set the `share` directive — but this is Windows UNC syntax; for SMB on macOS, just share the data disks directly (or share the pool dir, knowing clients will follow symlinks back to the per-disk paths).

### Built-in spin control commands
- `snapraid up` — spin up all disks (or use `-d <name>` for a specific disk).
- `snapraid down` — spin down all disks via `smartctl -s standby,now`.
- `snapraid probe` — show current spin state of each disk.
- **Macgotcha:** these commands shell out to `smartctl`. On macOS, USB-attached drives generally do NOT pass SMART/standby commands through the USB bridge; thus `snapraid down` may print errors or do nothing for USB drives. Thunderbolt-attached drives generally pass SMART through and the commands work.
- macOS-native alternative: `diskutil eject /dev/diskN` will unmount AND power down the drive — but that requires re-mounting before next use.
- Or: rely on enclosure/firmware-level spin-down + `pmset -a disksleep <minutes>`.

### Built-in temperature/safety controls (v13+)
- `temp_limit` config directive: SnapRAID auto-spins-down a disk that gets too hot.
- `-s, --spin-down-on-error` flag: spin down a failing disk to limit further damage.
- These pair very well with the spin-down model.

### snapraidd daemon (v14+)
- New daemon process introduced in 14.x. Persistent process that:
  - Schedules `up`/`diff`/`sync`/`scrub` according to user config
  - Provides "Safety Freeze" to halt sync if a sudden mass-deletion is detected
  - Integrates SMART + temperature monitoring
  - Is spin-down aware (won't wake disks unnecessarily)
  - Exposes a REST API and browser-based dashboard
  - Sends notifications to multiple channels (email, Apprise, Healthchecks, etc.)
- Most articles describe systemd integration; on macOS it would run as a launchd-managed service. **Verify on a test machine** that the daemon binary itself runs natively under macOS — Homebrew bottles for SnapRAID 14.4 cover the daemon.
- This effectively replaces snapraid-runner / snapraid-aio-script for v14+ users.

### Version-by-version macOS-relevant changes
- **SnapRAID 12** (~2021–22): Build/perf changes (MUSL stack, 16 MiB cache, parallel scan).
- **SnapRAID 13** (Oct 2025):
  - **"Supported UUID in macOS"** — fixed the long-standing "UUID is unsupported for disks" warning on macOS.
  - `temp_limit` config + auto-spin-down at temperature.
  - `probe` command added.
  - `-s --spin-down-on-error`.
  - SMART improvements (removed Load Cycle Count from failure prob; `smartignore`).
- **SnapRAID 14** (Mar 2026, current Homebrew):
  - **"Fixed a crash on macOS when filesystem doesn't report UUID"** — explicit Mac fix.
  - `.snapraidignore` for in-tree exclusion files.
  - `**` recursive glob in patterns.
  - `locate` command for parity offset diagnostics.
  - Fractional scrub percentages (`-p 1.5`).
  - Wear-level percentage in SMART output.
  - On ARM64 (incl. Apple Silicon): replaced inline assembly 128-bit multiplication with `__uint128_t`-based to avoid Apple Clang miscompilation.

### macOS-specific physical-offset and SMART caveats (still present)
- "Physical offsets not supported for disk 'd1'..." warning still appears on macOS — file ordering optimization is unavailable. Workaround: `--test-force-order-inode`. (Cosmetic; doesn't affect correctness.)
- "Smart is unsupported in this platform" — has been improved in v13+ but USB drives still won't pass SMART. Only Thunderbolt / built-in SATA drives expose SMART reliably on macOS.

---

## Round 9: Bitrot detection alternatives

If SnapRAID is not chosen (or as defense in depth), several simpler bitrot-detection tools work on macOS:
- **chkbit** (Homebrew: `brew install chkbit`) — Python-based, walks dirs and stores SHA hashes in `.chkbit` index files. Detects bitrot on subsequent runs. No parity/recovery, just detection.
- **hashdeep / md5deep** (Homebrew: `brew install hashdeep`) — Computes file hashes; can audit a tree against a stored manifest.
- **cshatag** — Stores SHA-256 of each file in extended attributes. Compares mtime + checksum to detect silent corruption. Caveat: macOS uses 1-second mtime resolution, and some filesystems (ExFAT) don't support xattrs.
- **bitrot** (Python, ambv/bitrot) — Similar to chkbit, SHA1 hashes in a sqlite db.
- **Carbon Copy Cloner / ChronoSync** — General Mac backup tools that include checksum-verified copy modes (not detection of in-place rot, but verification at backup time).

These tools detect rot but don't recover from it — so they're complementary to SnapRAID parity, or stand-ins if you only need monitoring.

---

## Round 10: Network sharing implications

- If SnapRAID-protected disks are exposed via SMB/AFP, clients writing during a `snapraid sync` will cause "files modified during sync" warnings. Sync will still finish but those files will be unprotected until next sync.
- Best practice: schedule sync at off-hours, or pause SMB shares during the sync window.
- snapraid-aio-script has options to pause Docker services during sync — analogous logic on macOS would `kill -STOP` the smbd/AFP processes (doable but ugly).
- The SnapRAID `pool` symlinks resolve fine over SMB; clients see the unified directory; macOS SMB server (`smbd` from `samba`/built-in) follows the symlinks transparently. Be aware of `smb.conf` `follow symlinks` / `wide links` semantics on built-in macOS SMB (modern macOS uses Apple's smbd which has different defaults than vanilla samba).

---

## Round 11: Decision matrix for the user

### Best fit for the stated requirements (independent FS + per-drive spin-down + parity)
1. **SnapRAID + built-in `pool` directive** (or no pooling at all) — clear winner. All three properties met natively. Mature, free, in Homebrew with arm64 bottles.
2. **SnapRAID + unionfs-fuse-macos** — adds union-mount nicety; needs FUSE (kext-pain pre-Tahoe; FSKit-clean on macOS 26).

### Real-time alternatives that drop one or more requirements
- **Apple Software RAID** (Disk Utility) — RAID 1 mirroring gives redundancy but ALL disks active, no parity for >2-disk arrays, no bitrot detection.
- **SoftRAID** — Real-time RAID 4/5 on macOS with a system extension. All disks active. Disks not independently readable.
- **OpenZFS on OS X** — Real-time, bitrot detection, snapshots, send/receive. All disks active (vdev pool). Spin-down practically unworkable. Apple Silicon support workable but bleeding-edge issues exist on macOS Tahoe.
- **PAR2** — Easy, file-level, but manual; bad fit for changing media libraries.

### Network-NAS alternatives if all-in-one isn't required
- Run a **TrueNAS / Unraid / OMV VM** on the Mac with PCIe passthrough — too complex for most.
- Buy a Synology / Asustor / TerraMaster appliance — outside the scope of this question.
