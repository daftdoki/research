# mergerfs-style options on modern macOS (Apple Silicon)

## Question / Goal

What are the realistic options in 2026 for getting
[mergerfs](https://github.com/trapexit/mergerfs)-style functionality - a
union/pooling filesystem that presents multiple physical disks as a single
mountpoint with policy-based file placement, while files remain readable as
plain files on each underlying disk - on a modern macOS (macOS 15 Sequoia /
macOS 26) Mac running on M-series Apple Silicon? See the
[Original Prompt](#original-prompt).

## Answer / Summary

**There is no native mergerfs build for macOS, and there likely never will be
an "official" one.** But as of April 2026 the situation is meaningfully better
than it was even a year ago:

- **Best practical answer (kext-free, closest to mergerfs):**
  [`rclone union`](https://rclone.org/union/) pointing at local disk
  directories, mounted via [fuse-t](https://www.fuse-t.org/) or macFUSE
  5.2.0's new FSKit backend. rclone union's policies (`epmfs`, `mfs`, `lfs`,
  `eplfs`, `ff`, `rand`, etc.) are explicitly "inspired by trapexit/mergerfs",
  and the no-kext mount path means no Reduced Security boot, no Recovery Mode
  changes, full Apple Silicon Full Security.
- **Closest to a real union filesystem (still kext-free if on macFUSE 5.2+
  FSKit backend):** `unionfs-fuse`. Fewer placement policies than mergerfs,
  but a true union FS rather than rclone's "pool of remotes".
- **The mergerfs program itself:** Linux only. Run it in a Linux VM (OrbStack,
  UTM, Parallels) and re-export to macOS via SMB or NFS if you need its exact
  semantics.
- **If "JBOD pool with snapshots and redundancy" is what you actually want
  (not literal mergerfs):** OpenZFS on macOS. Block-level, kext-based, but
  works on Apple Silicon.
- **Pure native macOS:** doesn't really exist for this use case. AppleRAID
  concat / SoftRAID give you a single block-level volume across disks but
  break mergerfs's central guarantee that files remain as plain files on each
  underlying disk.

The single biggest 2026 development is **macFUSE 5.2.0** (released
2026-04-09), which added an FSKit backend that runs entirely in userspace on
macOS 15.4+. **FUSE filesystems on Apple Silicon no longer require a kext.**
That removes the main historical pain point and unblocks the rclone-union
and unionfs-fuse paths above.

For additional and more detailed information see the
[research notes](notes.md).

## Methodology

1. Re-derived what mergerfs actually provides (pool semantics, placement
   policies, "plain files per disk" guarantee) from the project README.
2. Surveyed the 2026 state of FUSE on macOS: macFUSE release notes, fuse-t
   docs, FSKit progress, and Apple Silicon kext policy.
3. Surveyed candidate alternatives across five categories: FUSE union FSes,
   userspace FUSE (no-kext), native macOS storage (APFS/AppleRAID), real
   pooled filesystems (OpenZFS), and VM/container approaches.
4. Mapped each candidate against the mergerfs requirements list to pick a
   recommendation.

No code was written or benchmarks run - this is an options/landscape report.

## Results

### Capability matrix

| Approach | Apple Silicon | No kext | mergerfs-style policies | Files stay plain on each disk | Maintained 2026 | Notes |
|---|---|---|---|---|---|---|
| **rclone union + fuse-t** | Yes | Yes | Yes (mergerfs-inspired: epmfs, mfs, lfs, eplfs, ff, rand) | Yes | Yes | Closest realistic analog. Slightly slower directory listings on huge trees. |
| **rclone union + macFUSE 5.2 (FSKit backend)** | Yes | Yes (on macOS 15.4+) | Yes | Yes | Yes | Same as above, different FUSE engine. |
| **unionfs-fuse + macFUSE 5.2 (FSKit)** | Yes | Yes (15.4+) | Limited (basic union, RW/RO branches, COW) | Yes | Yes (rpodgorny fork active) | Real union FS but lacks mergerfs's placement policy zoo. Known Finder error -50 issue in some configs. |
| **mergerfs in a Linux VM, re-exported via SMB** | Yes | Yes (no host kext) | Yes (real mergerfs) | Yes (inside the VM); to macOS clients it's SMB | Yes | Highest fidelity to real mergerfs. VM + SMB overhead. Disk passthrough on Apple Silicon hypervisors is awkward; usually done with virtiofs of host directories or .img files. |
| **mergerfs in Docker (Docker Desktop / OrbStack / Colima)** | Yes | Yes | Yes | Depends on bind mount strategy | Yes | Effectively the same as the VM option since these all run a Linux VM under the hood. mergerfs's own GitHub discussion #1259 covers the mount-namespace gotchas. |
| **OpenZFS on macOS** | Yes | No (kext) | N/A (different model) | No (block-level) | Yes (lags Linux/FreeBSD) | Right answer if you actually want a *real pool* with redundancy, not literal mergerfs. |
| **AppleRAID concat / SoftRAID concat** | Yes | Yes | None | No (block-level) | Yes | Native, simple, but not the mergerfs model at all. Lose a disk = lose the set. |
| **APFS volume groups / space sharing** | Yes | Yes | N/A | N/A | Yes | Doesn't pool *across physical disks*. A container is one device. Not applicable. |
| **macFUSE classic kext + unionfs-fuse / mhddfs** | Yes (with Reduced Security) | No | Limited | Yes | macFUSE yes; mhddfs no | Older path. Works but requires the kext approval flow. |
| **Symlink farm / autofs / manual placement** | Yes | Yes | DIY | Yes | N/A | The "no software" answer. No transparent placement; you script it. |

### Key 2026 facts

- **macFUSE 5.2.0** ([release notes](https://macfuse.github.io/2026/04/09/macfuse-5.2.0.html)),
  released 2026-04-09, ships an FSKit backend. FUSE volumes can mount in
  userspace on macOS 15.4+ - **no kext, no Reduced Security mode**.
- **fuse-t** ([fuse-t.org](https://www.fuse-t.org/)) supports three backends:
  NFS, SMB, and native FSKit on macOS 26+.
- mergerfs itself remains Linux-only ([trapexit/mergerfs#115](https://github.com/trapexit/mergerfs/issues/115),
  [trapexit/mergerfs discussion #1259](https://github.com/trapexit/mergerfs/discussions/1259)).
- rclone union explicitly cites mergerfs as the inspiration for its policies
  and is a first-class user of fuse-t and macFUSE on macOS.

## Analysis

### Why this question is harder on macOS than Linux

mergerfs leans on Linux's mature FUSE kernel surface and lets you point it at
arbitrary host paths. macOS has historically had two obstacles:

1. **No native union filesystem.** macOS used to have a "union mounts"
   feature (`mount_unionfs`), but it has been deprecated for over a decade
   and was never policy-rich. APFS doesn't do unions across disks; a
   container is bound to one block device.
2. **Kext deprecation on Apple Silicon.** Third-party kexts require Recovery
   Mode security downgrade plus explicit user approval. Apple has been
   migrating filesystem development to FSKit, which is a userspace API. Until
   late 2025, FUSE on macOS effectively meant macFUSE-the-kext, which made
   "just install mergerfs" a non-starter for users who didn't want to weaken
   their boot security policy.

The macFUSE 5.2 FSKit backend (April 2026) is the inflection point. From here
on, FUSE-based unions on Apple Silicon look more like "install a userspace
package" and less like "modify your boot policy".

### Why "rclone union" is the sober pick

People reach for mergerfs for one of three reasons:

1. **Pool many disks into one mountpoint** - rclone union does this fine.
2. **Choose where new files land via policy** (most-free-space, existing-path
   most-free, first-found, etc.) - rclone union has these, named the same as
   mergerfs.
3. **Keep files as plain files on each underlying disk** so a disk pulled
   from the pool is still readable elsewhere - rclone union over local
   directories preserves this.

What you don't get vs real mergerfs:
- Some semantic differences (rclone union is designed around remote backends,
  so directory listings on huge local trees are slower, and a few POSIX
  edge-cases differ).
- Less battle-testing as a "media server pool" specifically.

For 90% of mergerfs use cases on a Mac (one media library, several disks,
"keep filling the emptiest drive"), it is a workable answer with no kext.

### When to skip macOS as the storage host entirely

If the goal is a long-term home-server-style media pool, the cleanest answer
is to **not** use macOS as the file server. Run TrueNAS / Unraid / a small
Linux box with mergerfs+SnapRAID, and let the Mac mount it over SMB. Apple
Silicon Macs are excellent clients of network storage and you sidestep the
entire FUSE/FSKit/kext situation.

### Caveats and risks

- **fuse-t and macFUSE FSKit backend are both relatively new.** Some apps
  (especially anything that does fancy fcntl locking, extended attributes,
  or expects specific filesystem types) can misbehave. Test your actual
  workload before committing.
- **Apple keeps changing the rules.** The kext path on Apple Silicon has been
  one OS upgrade away from breaking for years. The FSKit path is more
  durable but still maturing.
- **Hardlinks across branches are impossible** for any of these unions, just
  like mergerfs - that's a property of POSIX, not a macOS quirk.
- **Apple Photos / Music libraries don't tolerate union mounts well.** They
  expect a stable POSIX volume with specific xattr behavior; mergerfs and
  unionfs-fuse have historically had bugs in those corners. If the pool is
  for an iCloud-managed library, plan to test extensively.

## Files

- `README.md` - this report.
- `notes.md` - working notes captured during the investigation, including the
  initial survey and the verified findings from web searches.

## Original Prompt

> Research options for mergerfs style functionality on modern macOS on m series processors.
