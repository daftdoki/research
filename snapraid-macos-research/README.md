# SnapRAID-Like Storage on Modern macOS (Apple Silicon)

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

How can a modern macOS Apple Silicon machine (M-series) be set up with [SnapRAID](https://www.snapraid.it/)-like storage, where:

1. **Each disk hosts its own independent filesystem** — losing one disk does not corrupt the others.
2. **Individual disks can spin down** when idle to save power and reduce wear.
3. **Parity-based redundancy** can recover from drive failures.

Plus: what management, automation, and monitoring tools exist; what alternatives exist; and what the macOS-specific gotchas are. ([original prompt](#original-prompt))

## Answer / Summary

**SnapRAID itself is the right tool, and it runs natively on Apple Silicon today.** Homebrew ships precompiled `arm64` bottles of SnapRAID 14.4 for macOS Sonoma, Sequoia, and Tahoe (`brew install snapraid`). Recent releases (13.x in Oct 2025, 14.x in Mar 2026) added explicit macOS fixes: UUID detection, an Apple-Clang-safe ARM64 codepath, and a `probe`/spin-down model. SnapRAID's snapshot-based parity model is uniquely well suited to the three goals — disks stay independently readable, only the disk being accessed has to spin, and parity is computed on demand rather than continuously.

The big caveats on macOS are:

- **There is no mergerfs port for macOS.** Use SnapRAID's built-in `pool` directive (a symlink tree) for unification, or skip pooling entirely and let Plex/Jellyfin scan multiple library paths.
- **Per-drive spin-down via SnapRAID's `down`/`up` commands works through `smartctl`, which generally cannot reach drives over USB-to-SATA bridges.** Thunderbolt/native-SATA enclosures pass SMART through and work; USB enclosures rely on their own firmware sleep timer plus the global `pmset -a disksleep` setting.
- **Real-time RAID/ZFS solutions fail the spin-down and "independent disks" requirements**, so SnapRAID is the right model here. OpenZFS-on-OSX exists for Apple Silicon but its pools cannot keep disks spun down in practice.

For the canonical macOS recipe: pick a Thunderbolt JBOD enclosure (OWC ThunderBay 8, TerraMaster D8/D9 in Thunderbolt mode, or an M.2 SATA HBA in a Thunderbolt enclosure), format each disk as APFS, install `snapraid` + `smartmontools` + `chkbit` from Homebrew, drop a `snapraid.conf` with one parity disk per ~6 data disks, exclude macOS metadata directories (`.fseventsd`, `.Spotlight-V100`, `.DS_Store`, `.Trashes`, `._AppleDouble`), automate via either the new `snapraidd` daemon or `snapraid-runner` + a `launchd` LaunchAgent, and (optionally) expose a read-only unified view with `snapraid pool`. Add `pmset -a disksleep 15` + `pmset -a sleep 0` so disks sleep individually while the host stays awake.

For additional and more detailed information see the [research notes](notes.md).

## Why SnapRAID fits the three requirements

| Requirement | SnapRAID's behavior |
|---|---|
| Independent filesystems per disk | Each data disk is a regular APFS/HFS+ volume; pull a disk and it is fully readable on any Mac. SnapRAID only writes parity to dedicated parity disks. |
| Per-drive spin-down | Parity is updated only on `snapraid sync`; reads from a single file only spin up the disk holding that file. Built-in `up`/`down`/`probe` commands plus `temp_limit` thermal auto-spin-down (v13+). |
| Parity-based recovery | 1–6 parity disks; recovers up to N simultaneous failures. Beyond N, surviving disks remain readable. 128-bit SpookyHash detects silent corruption (bitrot). |

Real-time systems (Apple Software RAID, SoftRAID, ZFS, Btrfs) all fail at least the spin-down requirement and most fail the independent-filesystems requirement.

## Methodology

Surveyed the SnapRAID project, its Homebrew distribution, the SnapRAID FAQ and CLI manual, the SnapRAID change log, and macOS-specific bug threads on the SourceForge SnapRAID forum and Apple Developer Forums. Cross-referenced with the Perfect Media Server tech-stack docs, Michael's Tinkerings Mac mini NAS guide, blogs by community SnapRAID users on macOS, and the documentation for adjacent tools (mergerfs, unionfs-fuse-macos, FUSE-T, macFUSE 5.2.0 with FSKit, OpenZFS-on-OSX, smartmontools, chkbit, DriveDx). Pulled together the macOS-specific gotchas around APFS metadata files, `pmset` semantics, USB SMART passthrough, and `launchd` plist conventions.

## Results

### 1. SnapRAID on Apple Silicon (status)

| Aspect | Status |
|---|---|
| Homebrew formula | `snapraid` 14.4 |
| Apple Silicon bottles | arm64_tahoe ✅, arm64_sequoia ✅, arm64_sonoma ✅ |
| Native ARM64 codepath | Yes (v14 replaced inline asm with `__uint128_t` to avoid Apple Clang issue) |
| UUID detection on macOS | Yes (added in v13, crash on edge-case fixed in v14) |
| SMART on macOS | Partial — works on Thunderbolt/internal SATA; USB drives usually not (USB bridges don't pass SMART) |
| Physical-offset optimization | Not supported on macOS — cosmetic warning, sync still works (workaround `--test-force-order-inode`) |
| `pool` symlink command | Works on macOS (any OS with symlinks) |
| `up`/`down`/`probe` spin control | Works for Thunderbolt/SATA disks; limited for USB |
| `snapraidd` daemon | Present in 14.x; expected to run under launchd on macOS |

### 2. Pooling options on macOS

| Option | Verdict |
|---|---|
| `mergerfs` | **Unavailable.** Linux-only; no maintained Mac port. Old PR #384 abandoned. |
| `unionfs-fuse-macos` (WaterJuice fork) | Available with universal2 binaries; needs macFUSE/FSKit. Less feature-rich than mergerfs. |
| **SnapRAID `pool` directive** | **Recommended.** Built-in. Creates a read-only symlink tree at a path you choose. Works over SMB, transparent to Plex/Jellyfin/Emby. No FUSE dependency. |
| No pooling — multiple library paths | Simplest. Plex/Jellyfin accept multiple roots. Loses single-namespace view. |
| Manual symlink farm via script | Works; not worth the trouble vs `snapraid pool`. |

### 3. Drive spin-down toolbox on macOS

| Tool | What it does | Caveat |
|---|---|---|
| System Settings → Battery/Energy → "Put hard disks to sleep when possible" | Global toggle | Yes/No only; no per-drive control |
| `pmset -a disksleep <minutes>` | Sets system-wide disksleep timeout in minutes (`0` = "do nothing") | Global, not per-drive. `0` doesn't force "never" — drive firmware can still sleep. |
| `pmset -a sleep 0`, `pmset -a hibernatemode 0` | Keep the Mac awake (so it can run schedules) while still letting disks idle | Required for an always-on NAS |
| `snapraid down [-d disk]` | Issues `smartctl -s standby,now` | USB drives usually fail this; Thunderbolt/SATA fine |
| `diskutil eject /dev/diskN` | Unmounts + powers down a drive | Drive then has to be re-mounted before use |
| Enclosure firmware sleep timer | Most reliable for USB drives | Per-enclosure; some misbehave and *disconnect* drives, not just spin them down |
| DriveDx / smartmontools | Health monitoring + spin-state info | Needs `SATSMARTDriver` kext for USB on Apple Silicon |

### 4. Bitrot detection (with or without SnapRAID)

| Tool | Homebrew | Approach |
|---|---|---|
| **SnapRAID** | `brew install snapraid` | 128-bit SpookyHash per file; `scrub` verifies + fixes via parity |
| **chkbit** | `brew install chkbit` | Walks tree, writes `.chkbit` SHA index files |
| **hashdeep** | `brew install hashdeep` | Recursive hash sets; audit mode |
| **cshatag** | source / MacPorts | Stores SHA-256 in xattrs (skip on ExFAT) |
| **bitrot** (ambv) | `pip install bitrot` | SQLite-backed SHA1 index |

### 5. Alternative parity / redundancy options

| Option | Real-time? | Independent disks? | Spin-down? | Bitrot? | Apple Silicon? |
|---|:-:|:-:|:-:|:-:|:-:|
| **SnapRAID** | No (snapshot) | Yes | Yes | Yes (SpookyHash) | **Yes (native arm64)** |
| Apple Software RAID (Disk Utility) | Yes | No (stripe/mirror only) | No | No | Yes |
| SoftRAID 8 | Yes | No | No | No (parity only) | Yes (system extension) |
| OpenZFS on OS X | Yes | No (pool) | Effectively no | Yes | Yes; some Tahoe stability bugs |
| PAR2 / Parchive | Manual | Yes (file-level) | Yes | Indirect | Yes (MacPorts) |
| chkbit / hashdeep / cshatag | No | Yes | Yes | Yes (detect only) | Yes |
| Time Machine / CCC / SuperDuper | N/A (mirror backup) | Yes | Yes | No | Yes |
| TrueNAS / Unraid / OMV in a VM | Yes | Depends | No | Yes | Possible but impractical |

### 6. Management & automation tools

| Tool | macOS-friendly? | What it does |
|---|---|---|
| **`snapraidd`** (built into SnapRAID 14.x) | Should be — runs under launchd | Daemon mode: scheduled diff/sync/scrub, safety freeze on mass deletion, REST API, web dashboard |
| **`snapraid-runner`** (Chronial) | Yes, officially | Python 3.7+ wrapper, emails results, easy to schedule |
| **`snapraid-aio-script`** (auanasgheps) | Linux-focused; portable bash | Most features but assumes Linux conventions |
| **`snapper`** (firasdib) | Node.js, cross-platform | Modern runner |
| **Elucidate** (Smurf-IV) | ❌ Windows/.NET WinForms — not viable on Mac | GUI |
| **launchd** | Native macOS scheduler | Replaces cron; use a LaunchAgent in `~/Library/LaunchAgents` |
| **DriveDx** | Yes (paid) | SMART monitoring; supports USB via SATSMARTDriver |
| **smartmontools** | `brew install smartmontools` | `smartctl`, `smartd`; SATSMARTDriver needed for USB |
| **terminal-notifier / osascript** | Native | Notification Center alerts from scripts |
| **HealthChecks.io / Apprise** | Native | Dead-man's-switch + multi-channel notifications |

### 7. Hardware recommendations (per community consensus)

| Class | Examples | Why |
|---|---|---|
| Thunderbolt JBOD | OWC ThunderBay 8 / Flex 8, TerraMaster D8/D9 Thunderbolt models | Each bay surfaces as a separate volume; SMART passes through; per-bay spin-down |
| Thunderbolt M.2 HBA enclosure | Inateck USB4 enclosure + IOCREST JMB585+JMB575 HBA | Native SATA, ~2800 MB/s PCIe tunneling, full SMART |
| USB-C single-bay docks | Sabrent, OWC Drive Dock | One disk per dock; great for SnapRAID's "one filesystem per disk" model |
| USB multi-bay (cheap) | Yottamaster, Mediasonic ProBox | Risky on Apple Silicon — reports of drives disconnecting after hours. Often no SMART passthrough. |

Avoid hardware-RAID modes in any enclosure — set them to JBOD / "Single Drive" so each bay surfaces as an independent disk.

### 8. macOS-specific configuration cheatsheet

**`snapraid.conf` excerpt for macOS** (full annotated version in `examples/snapraid.conf`):

```conf
# Parity on one or two disks
parity /Volumes/Parity1/snapraid.parity
# 2-parity gives RAID-6-like resilience:
# 2-parity /Volumes/Parity2/snapraid.2-parity

# Multiple content file copies (each on a different disk)
content /Users/Shared/snapraid/snapraid.content
content /Volumes/Data1/snapraid.content
content /Volumes/Data2/snapraid.content
content /Volumes/Parity1/snapraid.content

# Each data disk is independent
data d1 /Volumes/Data1
data d2 /Volumes/Data2
data d3 /Volumes/Data3

# Pool directory: a virtual symlink tree unifying all data disks
pool /Volumes/Media

# macOS metadata to exclude
exclude *.unrecoverable
exclude .DS_Store
exclude .AppleDouble
exclude ._*
exclude .fseventsd
exclude .Spotlight-V100
exclude .Trashes
exclude .TemporaryItems
exclude .DocumentRevisions-V100
exclude .AppleDB
exclude .Thumbs.db

# Optional thermal auto-spin-down (v13+)
# temp_limit 50
```

**Power-management settings for an always-on Mac mini NAS:**

```sh
sudo pmset -a sleep 0          # don't sleep the Mac
sudo pmset -a disksleep 15     # idle disks spin down after 15 min
sudo pmset -a powernap 0       # disable Power Nap wakes
sudo pmset -a hibernatemode 0  # don't write hibernate image
sudo pmset -a tcpkeepalive 1   # keep network up
```

**LaunchAgent (`~/Library/LaunchAgents/it.snapraid.sync.plist`) running a runner at 03:30 nightly:**

See `examples/it.snapraid.sync.plist`. Load with:

```sh
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/it.snapraid.sync.plist
```

### 9. Operational workflow

A typical day-to-day cycle on a Mac running SnapRAID:

1. **Add/change files** on `/Volumes/DataN` as usual.
2. **Nightly (launchd)** runs `snapraid diff`, then `snapraid sync` if changes look sane, then `snapraid scrub -p 5 -o 10` (scrub 5% of the array per night, skipping files scrubbed in the last 10 days).
3. **Weekly**: run `snapraid status` and `snapraid smart` to check fragmentation, errors, and drive health.
4. **Drive failure**: replace the failed drive, mount it at the same path (e.g. `/Volumes/Data2`), run `snapraid -d d2 -l fix.log fix`, then `snapraid check`.
5. **Bitrot**: `scrub` finds a hash mismatch, marks it; `snapraid fix` rebuilds it from parity.

## Analysis

### Why this combination works

The "snapshot + independent filesystems" design of SnapRAID is the only common parity model that lets a disk sit fully powered down. Real-time systems (Apple Software RAID, SoftRAID, ZFS) must keep all members synchronized at write time, so every disk is at minimum spun and probed by the host on every transaction. SnapRAID instead operates in batch mode: at sync time it reads every changed file plus parity, and otherwise it is silent. That makes it the natural fit for a media-server use case where most disks are read-only most of the time.

### Why mergerfs is missed but not catastrophic

The Linux SnapRAID experience leans hard on mergerfs for write-balancing, transparent unified writes, and `most-free-space` policies. On macOS, SnapRAID's own `pool` directive plus the conscious choice to write directly to specific data disks (or have your app pick a disk) recovers most of the value. For read-heavy media libraries scanned by Plex/Jellyfin, the symlink-based `pool` is functionally indistinguishable from mergerfs for the indexer.

### Where macOS adds friction

1. **USB SMART passthrough is unreliable.** This affects `snapraid smart`, `snapraid down`, and DriveDx for cheap USB enclosures. Mitigations: prefer Thunderbolt; install the `SATSMARTDriver` kernel extension; or rely on enclosure firmware for sleep.
2. **Kernel extensions on Apple Silicon used to require Reduced Security boot.** This affected macFUSE and SATSMARTDriver. macOS 15.4+ (FSKit) and macFUSE 5.2.0 (April 2026) ship a user-space FSKit backend that bypasses this. On macOS 26 Tahoe the FUSE / SMART-driver pain is largely gone.
3. **APFS subtleties.** Time Machine local snapshots can fill a disk silently — periodically `tmutil deletelocalsnapshots`. SnapRAID is happy with APFS (stable inodes, journaling), and HFS+ is explicitly "acceptable" for parity per the SnapRAID FAQ.
4. **Case-insensitive default.** APFS/HFS+ are case-insensitive by default; if you migrate a disk between macOS and Linux, watch for case-collision rename issues.
5. **No mergerfs / no native union mount.** Already addressed via `snapraid pool` or multi-library scanning.

### When to choose something else

- **You need real-time integrity / snapshots / send-receive** — OpenZFS on OS X, accepting that disks will not spin down. Use Apple Silicon ZFS 2.3.0 (avoid 2.3.1-rc1 on macOS 26 due to reported watchdog panics). Disks not independently readable without ZFS.
- **You're comfortable buying an appliance** — Synology / Asustor / TerraMaster appliances wrap SnapRAID-like ideas (SHR/BTRFS or BasicMode + Snapshot Replication) without the DIY work, and offload power management entirely.
- **You only have a small static archive** — PAR2 plus an off-site backup is simpler than SnapRAID.

### Recommended starting build

A practical, low-power macOS SnapRAID NAS as of May 2026:

- **Host:** M-series Mac mini (M2/M4), 16 GB RAM (~1 GB per 16 TB SnapRAID rule).
- **Disks:** 3–4 large data drives + 1 parity drive in either an **OWC ThunderBay 8 (Thunderbolt 4)** in JBOD mode or **Inateck USB4 enclosure + IOCREST JMB585 HBA** for native SATA.
- **Filesystems:** Each drive APFS (one volume per container per drive). Parity drive same.
- **Software:** `brew install snapraid smartmontools chkbit terminal-notifier`. Optionally `brew install --cask drivedx`.
- **Automation:** `snapraidd` if running 14.x and you want the dashboard, otherwise `snapraid-runner` from launchd.
- **Pooling:** `pool /Volumes/Media` in `snapraid.conf`; point Plex/Jellyfin at `/Volumes/Media`.
- **Power:** `pmset -a sleep 0 disksleep 15 powernap 0 hibernatemode 0 tcpkeepalive 1`.
- **Off-site backup:** Carbon Copy Cloner or rclone to an external/cloud target — SnapRAID protects against drive failure and bitrot, **not** disaster, theft, or human error.

## Files

- `notes.md` — Running research notes (rounds 1–11), source quotes, and rejected alternatives.
- `README.md` — This report.
- `examples/snapraid.conf` — Annotated example `snapraid.conf` tuned for macOS Apple Silicon (APFS data + parity, content-file redundancy, full macOS exclusion list, optional thermal/`temp_limit` directive).
- `examples/it.snapraid.sync.plist` — LaunchAgent for nightly automated sync via `snapraid-runner`.
- `examples/snapraid-mac.sh` — Convenience shell wrapper for manual `diff`/`sync`/`scrub` with sane defaults and macOS Notification Center alerts.

## Original Prompt

> I want you to research solutions for snapraid like functionality on modern macOS running on an M series processor. The properties of snap raid I am most interested are the disks being independent file systems so that if one is lost, the data on the others remain accessible, the ability to spin down individual drives that aren't in use, and its parity based protection against drive failures. Snapraid itself, or alternatives that provide similar functionality are interesting. Also research the management and setup of these solutions, any other projects that help utilize them for macOS, and any relevant utilities or guides that help with setup, administration, and maintenance. Go broad and deep on this topic and be thorough.
