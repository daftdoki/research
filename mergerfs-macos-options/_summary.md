Modern macOS systems on Apple Silicon now offer practical mergerfs-style union/pooling filesystems without the need for low-level kernel extensions. Thanks to macFUSE 5.2.0's FSKit backend (released April 2026), tools like [rclone union](https://rclone.org/union/) and unionfs-fuse can be deployed fully in userspace, achieving policy-driven file placement and transparent access to files across multiple disks, with no compromise to system security. While mergerfs itself remains Linux-only, using a VM and network export is an option for legacy compatibility. Apple's own solutions (AppleRAID, SoftRAID) do not provide mergerfs's core guarantees (plain files on underlying disks), and OpenZFS offers redundancy but operates at the block level.

**Key Tools & Findings:**
- rclone union (with macFUSE 5.2+) offers placement policies nearly identical to mergerfs, in user mode.
- unionfs-fuse is an alternative, though less flexible than mergerfs in policy options.
- macFUSE 5.2.0 FSKit eliminates kernel extension requirements for FUSE filesystems on Apple Silicon.
- Official mergerfs is not available for macOS—VM export is required for precise mergerfs semantics.
- Native macOS pooling solutions do not satisfy mergerfs-style requirements for filesystem-level plain file access.
