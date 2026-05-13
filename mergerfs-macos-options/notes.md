# Research notes: mergerfs-style functionality on modern macOS (Apple Silicon)

## Goal

Find ways to get mergerfs-like functionality (a union/pooling filesystem that
presents multiple underlying drives as a single mountpoint, with policy-based
file placement) on modern macOS running on M-series (Apple Silicon) machines.

## What mergerfs does (the baseline)

mergerfs is a FUSE-based "union" filesystem on Linux. Key properties to keep
in mind when looking for alternatives:

- Pools several "branches" (directories on different filesystems/disks) under a
  single mountpoint.
- Files remain as plain files on the underlying disks - no special on-disk
  format. Pull a disk and you can read it on any system.
- Per-operation "policy" controls which branch a new file is created on
  (e.g. `epmfs` = existing path, most free space; `mfs` = most free space;
  `ff` = first found; `lfs`, `rand`, etc.).
- Read/lookup typically picks first-found across branches.
- Files do NOT get split across branches (it isn't striping/RAID-0). Free
  space is the sum of the branches but a single file must fit on one branch.
- No redundancy by itself. People often pair it with SnapRAID.
- Read-write, supports xattrs, hardlinks (with caveats), and many POSIX
  semantics depending on policies.

So the requirements for an alternative on macOS are roughly:
- Multiple physical disks combined into one logical mountpoint
- Files stay readable as plain files on the underlying disks
- Some kind of file-placement policy
- Tolerable performance, ideally not requiring kexts (since modern macOS
  kernel extensions are heavily restricted on Apple Silicon)

## macOS / Apple Silicon constraints

The big issue is that macOS does not have a native union filesystem in the
mergerfs sense. The typical answer on Linux is FUSE; on macOS that means
macFUSE.

Key facts about macFUSE on Apple Silicon:

- macFUSE is a kernel extension (kext). On Apple Silicon, third-party kexts
  require:
    1. Reduced Security mode (boot to Recovery, lower the security policy).
    2. Allowing user-managed kexts in System Settings > Privacy & Security.
    3. A reboot to "activate" the kext.
- This is doable but disliked: it weakens the secure boot policy and Apple has
  publicly stated kexts are deprecated in favor of System Extensions /
  DriverKit / FSKit. Each macOS major release has caused churn for macFUSE.
- macFUSE 4.x supports Apple Silicon. Benjamin Fleischer (the maintainer) has
  kept it working but it lags releases and the licensing changed in 4.x to a
  more restrictive license (not OSS).
- macFUSE does run mergerfs's nearest cousins on macOS - e.g. unionfs-fuse,
  mhddfs, fuse-overlayfs - but none of those are mergerfs itself, and most
  haven't been ported / aren't maintained for macOS specifically.
- macOS 15+ (Sequoia) introduces FSKit, a userspace filesystem framework
  intended as the successor to kexts. As of late 2025 FSKit is still maturing
  and there is no mergerfs port to it. fuse-t and other projects are exploring
  this space.

So: the kext path is shrinking. Anything that depends on macFUSE long-term is
on borrowed time - it works now but is fragile across OS upgrades.

## Option survey

### 1. macFUSE + a union FUSE filesystem

Closest to "mergerfs on macOS":

- **unionfs-fuse**: Available via Homebrew. Branches with read-only or
  read-write modes, copy-on-write semantics. Older codebase, less active than
  mergerfs. Doesn't have mergerfs's rich policy set.
- **mhddfs**: Older, abandoned. Linux-centric.
- **fuse-overlayfs**: Designed for container overlay use, not really a
  general-purpose "JBOD pool".
- **mergerfs itself**: There has historically been talk of a macOS build but
  the official project is Linux-only. Some people have built it against
  macFUSE with patches but it isn't a supported configuration.

Practical state (2025/2026): unionfs-fuse via macFUSE is the only realistic
"mergerfs-style" FUSE option natively on macOS. It works but you eat the kext
cost and you don't get mergerfs's policies.

### 2. fuse-t (FUSE-T) - kext-free FUSE on macOS

fuse-t is a relatively new project that implements the FUSE protocol on macOS
*without* a kext, by using NFS as the transport (a userland server speaks the
FUSE API to apps but talks NFS to the kernel).

- No kext, no security policy changes, works on Apple Silicon.
- Aims to be a drop-in for macFUSE.
- Caveats: NFS-based plumbing means some semantics differ (locking, certain
  syscalls, performance for some workloads). Not 100% compatible with every
  macFUSE consumer.
- Closed-source for some components, but free for personal use.
- Could in principle host unionfs-fuse-style binaries; in practice you mostly
  see it used for sshfs/rclone mounts.

This is the most promising "no-kext" path if a FUSE-based union filesystem is
acceptable.

### 3. Native macOS approaches (no FUSE)

These don't give you a true union filesystem but can cover some use cases:

- **APFS volume groups / containers**: Multiple APFS volumes share a
  container's free space ("space sharing"), but a *container* is bound to a
  single GPT partition on a single device. You cannot put one APFS container
  across multiple physical disks. So this doesn't pool disks.
- **Apple RAID (AppleRAID via diskutil)**: Supports concatenation (JBOD/SPAN),
  mirror, and stripe. JBOD/concat pools two or more disks into one logical
  volume, but:
    - You must format the resulting set; data on the disks isn't preserved.
    - File layout is at the block level - you can't pull a disk and read its
      files independently. Lose one disk in a concat set and you've likely
      lost the whole set.
    - This is the opposite of mergerfs's "files remain as plain files" model.
- **Symlink farms / `mkdir`+`rsync` workflows**: Manual but reliable. Some
  people just symlink into a single directory tree from multiple disks. Tools
  like `autofs` or `automount` can mount disks on demand, but you still have
  to manage placement yourself.
- **Disk Utility "concat" / Logical Volume**: Same caveats as AppleRAID above.
- **Time Machine network volumes / SMB / AFP**: Not relevant here.

None of these match mergerfs's "JBOD with file-level visibility and a
placement policy" model.

### 4. ZFS on macOS (OpenZFS)

OpenZFS on macOS (a.k.a. zfs-macos / OpenZFSonOSX) is maintained and supports
Apple Silicon, with some caveats around kext signing similar to macFUSE.

- Real pooled storage (zpool with multiple vdevs).
- Not "file-level transparent" - data lives in ZFS, you can't pull one disk
  and read files off it, so it's the wrong model if "plain files on every
  disk" is a hard requirement.
- But for many users who say "mergerfs" they really mean "I want one big
  volume across N disks with snapshots and self-healing" - in which case ZFS
  is arguably a better answer. With Apple Silicon, OpenZFS works but you again
  need to allow user kexts.

### 5. Linux VM with mergerfs (passthrough)

Run a Linux VM on the Mac, use mergerfs there, and re-export to macOS:

- Hypervisors on Apple Silicon: UTM (QEMU front-end), Parallels, VMware
  Fusion, OrbStack, Apple Virtualization framework directly.
- Disk passthrough: full block-device passthrough (`/dev/diskN`) is awkward
  on macOS hypervisors. UTM/QEMU can attach raw disks but it requires
  unmounting the disk in macOS, running the hypervisor with appropriate
  privileges, and (for Apple Virtualization framework) is restricted.
- Easier path: pass disks as VirtioFS / file-based virtual disks, run mergerfs
  in the VM across them, share back to macOS via SMB or NFS.
- Cost: VM overhead, dual mounting story, files no longer "plain on every
  disk" if you used .img files, network filesystem semantics on the host.
- Specific options:
    - **OrbStack** is a fast, Apple-Silicon-native Linux VM that supports
      passing host directories. You could put each disk's mountpoint into the
      VM via virtiofs and run mergerfs over them, then SMB-share back. Adds
      latency but no kext.
    - **UTM** with VirtIO can do something similar.

### 6. Containers (Docker Desktop, Colima, OrbStack)

Same idea as a VM but more lightweight. mergerfs in a container with bind
mounts of host disks, exporting via SMB/NFS. All of these on Apple Silicon
ultimately run a Linux VM under the hood, so the considerations are the same
as #5.

### 7. Application-level "pool" tools

Things that mimic the user-facing benefit (one big library across many disks)
without being a real filesystem:

- **rclone union**: rclone has a "union" remote that combines multiple
  backends (including local directories) with policies similar to mergerfs
  (`epmfs`, `mfs`, `ff`...). You can `rclone mount` it via macFUSE OR fuse-t.
  This is probably the closest spiritual analog to mergerfs that runs on
  Apple Silicon today, especially with fuse-t (no kext).
- **Plex/Jellyfin/Roon multi-library**: media servers can index multiple
  folders as one library. Doesn't help if the consumer is the Finder, but
  fine for media workflows.
- **Photos / Music / etc.**: these typically demand a single library file and
  don't tolerate union mounts well anyway.

### 8. JBOD via third-party drivers / hardware

- Hardware DAS enclosures with built-in JBOD/concat (e.g. some OWC, TerraMaster
  units): same caveats as AppleRAID concat - block-level, not file-level.
- SoftRAID on Apple Silicon: commercial, supports stripe/mirror/concat;
  block-level.

## Things worth verifying with web sources

- Current state of macFUSE on macOS 15/16 + Apple Silicon (kext flow,
  versions).
- fuse-t status (Apple Silicon support, license, maturity).
- Whether mergerfs has any official or near-official macOS build path.
- rclone union policies and mount on macOS.
- FSKit progress and any union-fs experiments on it.
- OpenZFS on macOS Apple Silicon status.

## Web findings (April 2026)

### macFUSE

- Latest release is **macFUSE 5.2.0**, released 2026-04-09
  (https://macfuse.github.io/2026/04/09/macfuse-5.2.0.html). Universal /
  Apple Silicon supported, macOS 12+.
- Big news: **5.2.0 ships an FSKit backend** that mounts volumes entirely in
  user space, using the FSKit API available in macOS 15.4+. **No kext, no
  Reduced Security boot, no Recovery Mode dance.** The classic kext backend
  still exists for older macOS.
- This dramatically changes the calculus: a FUSE-based union filesystem on
  Apple Silicon no longer requires kexts.
- Kexts on Apple Silicon are still doable on older macFUSE / older macOS but
  require Reduced Security mode + allowing user kexts + reboot, which Apple
  is steadily de-emphasizing.

### fuse-t

- (https://www.fuse-t.org/) Userspace FUSE impl for macOS, no kext from day
  one. Originally NFS-based; **as of 2026 it supports three backends: NFS,
  SMB, and native FSKit on macOS 26 and later.**
- Apple Silicon supported. Free for personal use.
- Not 100% identical to macFUSE in semantics (locking, certain syscalls) but
  improving.
- Used by rclone, sshfs ports, etc.

### mergerfs itself

- The official trapexit/mergerfs project remains Linux-only. There have been
  long-standing GitHub issues (#115 etc.) about macOS builds; nothing
  official.
- Discussion #1259 on the mergerfs repo covers running it inside Docker on
  macOS - basically possible because Docker Desktop / OrbStack run a Linux
  VM, but mounting from inside that VM back to macOS is the awkward part.
- Bottom line: there is no native mergerfs build for macOS / Apple Silicon
  in 2026.

### unionfs-fuse

- rpodgorny/unionfs-fuse is alive; macOS builds work via macFUSE.
- WaterJuice/unionfs-fuse-macos is a fork with macOS-specific tweaks.
- Universal2 binaries exist for some downstream packagers, so Apple Silicon
  is supported.
- Lacks mergerfs's rich policy set (epmfs, mfs, lfs, eplus, etc.) but covers
  the basic union case.
- Known issue: Finder copies can hit error -50 in some configurations (open
  GitHub issue #92).

### rclone union

- (https://rclone.org/union/) Mature, actively maintained. Policies are
  explicitly "inspired by trapexit/mergerfs".
- Supports policies including epmfs, mfs, lfs, eplfs, ff, rand, lus and
  others, with a `min_free_space` knob for the lfs/eplfs family.
- Can be mounted on macOS via either macFUSE or fuse-t.
- Slightly different semantics from mergerfs (rclone is designed around
  remote filesystems, so directory listing performance can be slow vs
  mergerfs on local disks). For pure local-disk pooling, mergerfs is faster
  on Linux; on macOS, rclone union over fuse-t is the most realistic
  no-kext analog.

### FSKit

- (https://eclecticlight.co/2024/06/26/how-file-systems-can-change-in-sequoia-with-fskit/)
  Apple's FSKit was introduced in macOS 15 (Sequoia) and matured through
  macOS 26. It's the official "file systems in user space" framework
  replacing kexts.
- macFUSE 5.2.0 and fuse-t can both target it.
- There are early experiments porting union-style filesystems directly to
  FSKit (mentioned in HN/Apple Developer Forums threads), but nothing
  production-ready as a "mergerfs replacement" yet.
- Sandbox restrictions in FSKit make accessing arbitrary user-provided paths
  awkward, which is a real obstacle for a mergerfs port (mergerfs's whole
  point is "give me these N directories").

### OpenZFS on macOS

- openzfsonosx project is alive, supports Apple Silicon, but lags Linux/
  FreeBSD trees. Tested most heavily on older macOS.
- Still relies on a kext, with the same Reduced Security flow as macFUSE
  pre-5.2.
- Different model from mergerfs (block-level pool, not file-level
  transparent). Right answer for "I want one big pool with snapshots and
  self-healing"; wrong answer for "files must remain plain on each disk".

## Updated bottom-line recommendation

Given the April 2026 state of the world:

1. **First choice for kext-free, mergerfs-ish on Apple Silicon today**:
   rclone union + fuse-t (or macFUSE 5.2 with the FSKit backend), pointing
   at local disk paths. This gives you the policy-based file placement
   ("files stay as plain files on each disk", epmfs/mfs/etc.) without a
   kext.
2. **Second choice if you want closer to mergerfs semantics**: unionfs-fuse
   on top of macFUSE 5.2 (FSKit backend). Fewer policies than mergerfs but
   simpler, and it's a true union FS.
3. **If you actually wanted "one big pool with redundancy"**: OpenZFS on
   macOS, accepting the kext requirement. Or skip macOS as the storage host
   and use a NAS / Linux box.
4. **If you really want mergerfs the program**: run it in a Linux VM
   (OrbStack / UTM / Parallels) and re-export via SMB. Adds latency, gives
   you the real thing.
5. **For pure native macOS without third-party software**: there is no good
   answer. AppleRAID concat / SoftRAID give you a single pooled volume but
   only at the block level - a far cry from mergerfs.

## Open questions for the user (not blocking the report)

- What's the actual workload? Media library? Backups? Build artifacts?
- Is "files stay as plain files on each disk" a hard requirement (the main
  reason people pick mergerfs over ZFS/RAID)?
- How many disks, what size?
- Are kexts and the recovery-mode reduced-security flow acceptable?

