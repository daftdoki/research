# Presenting a USB Drive to a Computer, Backed by a Network Drive

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

Build or identify a solution that makes a host computer (or appliance) see a
**normal, plug-and-play USB drive**, while the actual bytes live on a **network
drive** — a NAS over SMB/NFS, an iSCSI target, or cloud storage. The classic
use case: some device only accepts a USB stick (an old PC, a TV, a car head
unit, a CNC/3D printer, a sampler, a photocopier, a server's BIOS) but you want
its contents to live centrally and update over the network. See the
[Original Prompt](#original-prompt).

## Answer / Summary

**This is a solved problem, and the standard mechanism is Linux *USB gadget
mode*: a small Linux board (a Raspberry Pi Zero 2 W / 4 / 5 or similar) plugs
into the host's USB port and emulates a USB Mass Storage disk, while a backing
store that lives on the network supplies the blocks.** There is no pure-software
way to do this from the macOS/Windows host alone — presenting a USB device
requires hardware with a USB *device/OTG* controller, so a small bridge board
is unavoidable (unless you buy an appliance that is exactly that board in a
box).

The one constraint that shapes every design is **block-level cache coherency**:
USB Mass Storage is a *block* protocol, and whoever mounts the filesystem (the
host) owns the cache and assumes exclusive ownership of the blocks. You cannot
safely have the host *and* the bridge writing the same filesystem at once.
Pick the pattern that respects this:

| Goal | Recommended solution | Coherency model |
|---|---|---|
| Real, **writable** USB disk, NAS-backed, correct block semantics | **Pi USB gadget fed by an iSCSI LUN** (`usb-gadget-iscsi.sh`) | Host is sole writer; blocks ride iSCSI back to the NAS |
| Dead simple, **read-mostly**, updated occasionally | **Disk image file on an NFS/SMB share + gadget** (`usb-gadget-imagefile.sh`) | Host is sole writer; push updates via `forced_eject` re-read |
| Central **boot/install media** (ISO/flash), not a live data drive | **PiKVM / JetKVM / Sipeed NanoKVM** virtual-media appliance | Upload image to appliance; host boots/reads it |
| **File-level** access, host doesn't need a true block disk | **MTP gadget** (uMTP-Responder) over a mounted network FS | File-level, far more forgiving of concurrent writers |

**Top recommendation for "a real USB drive backed by my NAS": a Raspberry Pi
(4, 5, or Zero 2 W) in USB gadget mode, fed by an iSCSI LUN exported from the
NAS.** iSCSI is the key: the mass-storage gadget needs a *block device*, iSCSI
gives the Pi exactly that with the blocks living on the network, so the host's
writes are committed back to the NAS with correct semantics. NFS/SMB shares
can't be fed to the gadget directly — you'd have to put an image *file* on them
(the simpler, read-mostly option).

For additional and more detailed information see the [research notes](notes.md).

## How it works

### The mechanism: USB gadget mode

A USB link has a *host* side and a *device* side. Normal computers are USB
hosts. To **appear as** a USB drive you need hardware that can act as a USB
*device*, i.e. a USB-OTG/peripheral controller (`dwc2` on the Pi). The Linux
kernel's **libcomposite / configfs** gadget framework then loads the
`usb_f_mass_storage` function and points it at a backing store — a block device
or an image file — and the host enumerates a brand-new USB disk.

```
 NAS / server                 Bridge board (Pi)                Host computer
 ┌───────────┐   network     ┌──────────────────┐   USB-OTG   ┌───────────┐
 │ iSCSI LUN │ ────────────▶ │ open-iscsi /dev/sdX          │ ──────────▶ │ "USB     │
 │  (blocks) │  (SCSI/blocks)│  → usb_f_mass_storage (gadget)│   cable     │  drive"  │
 └───────────┘               └──────────────────┘             └───────────┘
```

Pi models with a usable device-mode port: **Zero / Zero 2 W, A/A+, 3 A+, 4, 5,
CM4/CM5**. Enable it by adding `dtoverlay=dwc2,dr_mode=peripheral` to
`config.txt` and `dwc2` to `/etc/modules`. (FreeBSD and many other embedded
SoCs can do this too.)

### The hard part: block-level coherency

USB Mass Storage moves **blocks**, not files. The host mounts a filesystem on
those blocks and caches it, assuming nobody else touches the disk. So:

- **Only one side may write.** In practice the *host* is the writer; the bridge
  must not also mount/modify the same filesystem live. Two writers ⇒ corruption.
- **To push a network-side update to the host**, you must make the host re-read
  the medium. The mainline kernel exposes a `forced_eject` configfs attribute
  (the PiKVM/Devaev patch) that ejects the medium so the host re-enumerates;
  then you swap in the new backing file. Re-plugging or toggling the gadget
  works too.
- **Live bidirectional shared R/W at the block level is not safely possible.**
  If you need that, use the **MTP** (file-level) approach instead, and accept
  that the host sees a "media device," not a mounted volume.

## The four solutions in detail

### 1. iSCSI LUN → USB gadget (best for a real, writable NAS-backed disk)

The NAS exports an iSCSI target (TrueNAS, Synology, `targetcli`/LIO on Linux,
etc.). The Pi runs `open-iscsi`, logs in, gets a `/dev/sdX` block device, and
feeds *that* into the gadget. Because the network carries SCSI blocks end to
end, the host's writes land on the LUN with proper block semantics — this is
the most faithful "it's just a USB disk" experience.

- Reference projects: **`jwmullally/openwrt-rpi4-iscsi-to-usb-bridge`** (a
  prebuilt OpenWrt RPi4 image; reported ~41 MB/s, ~0.6 ms latency) and **Matt
  Olan's "piSCSI USB drive" series**.
- See **[`usb-gadget-iscsi.sh`](usb-gadget-iscsi.sh)** in this folder for a
  self-contained libcomposite/configfs reference implementation.

### 2. Image file on an NFS/SMB share → USB gadget (simplest, read-mostly)

The Pi mounts the NAS share, keeps a `files.img` on it, and exports that image.
Easiest to stand up, but you're layering a block image on a file protocol on
the network; the share must be mounted before the gadget binds, and it's still
single-writer. Best when the content changes occasionally and you can re-present
the medium (via `forced_eject`) after updating it.

- Reference project: **`DanBuchan/Networked_USB_Mass_Storage`** (uses the older
  `g_mass_storage` module; the modern path is libcomposite).
- See **[`usb-gadget-imagefile.sh`](usb-gadget-imagefile.sh)**. Swap the SMB/NFS
  mount for an `rclone mount` to back it with cloud storage instead.

### 3. Off-the-shelf virtual-media appliances (buy, don't build)

If you mainly need **boot/install media or an occasionally-swapped image** and
don't want to build anything:

- **PiKVM** — emulates a USB flash drive or CD/DVD to the host, available even
  in BIOS/UEFI. Images are uploaded via the web UI or rsync; NFS/Samba are
  mounted *locally on the Pi*, not live-streamed to the host.
- **JetKVM** — "Mount Drive": virtual CD/DVD or disk, upload an ISO, install via
  browser.
- **Sipeed NanoKVM** — cheap RISC-V board; virtual mass storage from images or
  block devices, and can also expose a USB NIC.

These are KVM-over-IP devices whose virtual-media feature is exactly the
gadget-mode trick in a polished box. They are *not* designed as a live,
continuously-network-synced data drive.

### 4. IODD enclosures (related, but NOT network-backed)

The **IODD 2541 / ST400** are hardware enclosures that turn image files
(ISO/VHD/VMDK) stored on their *own internal SSD* into virtual ODD/HDD drives.
Excellent for carrying many bootable images on one device, but the images live
on the enclosure's disk, not on the network — so they don't satisfy the
"backed by a network drive" requirement on their own.

### What does *not* fit

**"USB over IP" tools — FlexiHub, USB Network Gate, `usbip`** — share a *real*
USB device across the network in the **opposite** direction (they let a remote
machine use a USB device physically plugged in elsewhere). They do not
synthesize a USB drive out of a network share, so they don't solve this problem.

## Files

- **`README.md`** — This report.
- **`notes.md`** — Research log, findings, and sources.
- **`usb-gadget-iscsi.sh`** — Reference script: present an iSCSI LUN as a USB
  Mass Storage drive via libcomposite/configfs on a Pi (the recommended,
  block-faithful approach). `up` / `down` subcommands.
- **`usb-gadget-imagefile.sh`** — Reference script: present a disk image stored
  on an NFS/SMB share (or rclone/cloud) as a USB drive (the simple, read-mostly
  approach), including the `forced_eject` re-read note.

> **Note:** the scripts were written from the kernel configfs gadget
> documentation and the cited projects and pass `bash -n` syntax checks, but
> were **not** run end-to-end in the research environment, which has no USB-OTG
> hardware. Treat them as reference implementations to adapt to your board and
> NAS.

## Sources

- [Mass Storage Gadget (MSG) — Linux Kernel docs](https://docs.kernel.org/usb/mass-storage.html)
- [Linux USB gadget configured through configfs — Kernel docs](https://docs.kernel.org/usb/gadget_configfs.html)
- [`forced_eject` attribute patch (Devaev/PiKVM)](https://lore.kernel.org/lkml/20220710201605.211434-1-mdevaev@gmail.com/t/)
- [jwmullally/openwrt-rpi4-iscsi-to-usb-bridge](https://github.com/jwmullally/openwrt-rpi4-iscsi-to-usb-bridge)
- [Matt Olan — Making a piSCSI USB Drive](https://matt.olan.me/post/making-a-piscsi-usb-drive-part-1/)
- [DanBuchan/Networked_USB_Mass_Storage](https://github.com/DanBuchan/Networked_USB_Mass_Storage)
- [Pi Zero as USB Mass storage / SMB — Raspberry Pi Forums](https://forums.raspberrypi.com/viewtopic.php?t=191662)
- [PiKVM Mass Storage Drive (MSD)](https://docs.pikvm.org/msd/)
- [JetKVM — Mount Drive](https://jetkvm.com/docs/peripheral-devices/mount-drive)
- [Sipeed NanoKVM — Virtual Storage & Network](https://deepwiki.com/sipeed/NanoKVM/3.3-virtual-storage-and-network)
- [IODD ST400 / 2541](https://help.iodd.kr/product-reference-wiki/iodd-st400)
- [uMTP-Responder (MTP gadget, Viveris)](https://github.com/viveris/uMTP-Responder)
- [FreeBSD Handbook — USB Device Mode / USB OTG](https://docs.freebsd.org/en/books/handbook/usb-device-mode/)

## Original Prompt

> I'd like to build or identity a solution for presenting a usb drive to a computer that is backed by a network drive.
