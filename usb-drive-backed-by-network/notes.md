# USB drive presented to a computer, backed by a network drive — Notes

## Goal
Build or identify a solution where a host computer sees a normal USB drive
(mass-storage / plug-and-play), but the actual bytes live on a network drive
(NAS over SMB/NFS, an NBD/iSCSI target, or cloud storage).

## Key questions to answer
- What is the standard mechanism? (Linux USB gadget mode)
- How do you back the gadget by network storage? (image file on NFS/SMB,
  NBD, iSCSI, rclone, etc.)
- What is the hard problem? (block-level coherency: host owns the FS cache)
- File-level alternatives that dodge coherency (MTP gadget)
- Off-the-shelf hardware/appliances (PiKVM, JetKVM, NanoKVM, IODD, USBoNET...)
- Recommendation + a reference setup.

## Work log

### Findings

**The core mechanism**: Linux USB *gadget mode*. A small Linux board with a
USB device/OTG-capable controller (dwc2) presents itself to a host computer as
a USB device. The `g_mass_storage` / `usb_f_mass_storage` (libcomposite via
configfs) function exports a *block device or image file* as a USB Mass Storage
(BOT/UAS) disk. Pi models that work: Zero/Zero 2 W, A/A+, Pi 4, Pi 5 (USB-C
data port in dwc2 peripheral mode), CM4/CM5, plus many other SoCs and FreeBSD.

**The hard problem = block-level cache coherency.** USB Mass Storage is a
*block* protocol. Whoever mounts the filesystem (the host) owns the page cache
and assumes exclusive ownership of the blocks. If both the gadget side and the
host mount the same FS read-write, they corrupt each other — neither can tell
the other "I changed blocks." This is THE constraint that shapes every design.

Consequences:
- Safe RW from the host: host is the only writer. The bridge must not also
  mount/modify it live.
- To push an updated image from the network -> host, force the host to re-read:
  kernel `forced_eject` configfs attr (Devaev/PiKVM patch, mainline) ejects the
  medium so the host re-enumerates; or re-plug / toggle the gadget.
- Bidirectional live R/W "shared" access is not safely possible at block level.

**Backing the gadget by the network — three patterns:**

1. **iSCSI LUN over the network (BEST for block-faithful).** NAS/server exports
   an iSCSI target (a real LUN). Bridge runs open-iscsi, gets /dev/sdX, feeds
   that into the gadget. Network carries SCSI blocks, so host writes go all the
   way back to the LUN with proper block semantics. Projects:
   jwmullally/openwrt-rpi4-iscsi-to-usb-bridge (OpenWrt RPi4 image, ~41 MB/s,
   0.6 ms latency); Matt Olan's "piSCSI USB drive" series. Note: "mass storage
   gadget expects a block device, so it cannot use NFS/SMB directly."

2. **Image file on an NFS/SMB share, mounted by the bridge.** Bridge mounts the
   share, dd-creates files.img, exports the image via the gadget. Simple, works,
   but: (a) share must be up before the gadget starts (boot-order), (b) block
   image on top of a file protocol on top of the network — more layers, (c)
   same single-writer rule. Project: DanBuchan/Networked_USB_Mass_Storage
   (Gotek-style, still uses deprecated g_mass_storage).

3. **rclone/cloud + local image cache.** Same as (2) but backing store is a
   cloud remote via rclone mount/vfs. Higher latency; fine for read-mostly.

**File-level alternative that DODGES block coherency: MTP gadget.** Present as a
"media device" (like a phone) instead of a disk. MTP is file-level, so the
bridge can keep a normal mounted network filesystem and serve files from it.
Cost: host sees an MTP device, NOT a drive letter/mounted volume. macOS needs
an MTP app; appliances that demand a real "USB drive" won't accept it.
Implemented via configfs ffs/MTP + a userspace responder (uMTP-Responder).

**Off-the-shelf appliances (virtual media):**
- PiKVM MSD: emulates USB flash drive or CD/DVD, even in BIOS. Images via web
  UI / rsync; NFS/Samba mounted locally, not live-streamed. Pi 2+/V2+.
- JetKVM Mount Drive: virtual CD/DVD or disk, upload ISO, browser install.
- Sipeed NanoKVM: virtual mass storage from images/block devices; cheap RISC-V.
- IODD 2541 / ST400: hardware enclosure turning image files on its OWN internal
  SSD into virtual ODD/HDD. NOT network-backed.

**"USB over IP" tools (FlexiHub, USB Network Gate, usbip):** share a *real* USB
device across the network in the OPPOSITE direction. Do not fit.

### Conclusion / recommendation
- Real, writable USB *drive*, NAS-backed, correct block semantics → **Pi
  (4/5/Zero 2 W) USB gadget fed by an iSCSI LUN** (libcomposite/configfs).
- Dead simple, read-mostly → **image file on NFS/SMB share + gadget**, push
  updates with forced_eject re-enumeration.
- Central boot/install media, not a live data drive → **PiKVM/JetKVM/NanoKVM**.
- File-level multi-writer, host doesn't need a true block disk → **MTP gadget**.

### Notes on building/testing
- This research was done in a cloud container with no USB-OTG hardware, so the
  reference scripts are written from the kernel configfs docs + the cited
  projects but were NOT run end-to-end here. They are reference implementations.
