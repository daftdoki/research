#!/usr/bin/env bash
#
# usb-gadget-imagefile.sh
# ---------------------------------------------------------------------------
# Simpler alternative to the iSCSI bridge: keep a disk *image file* on an
# NFS/SMB share, mount the share on the Pi, and export the image to the host
# as a USB Mass Storage drive via libcomposite/configfs.
#
# Data path:   NAS NFS/SMB share -> Pi mount -> /srv/usb/files.img ->
#              usb_f_mass_storage -> USB-C OTG -> host sees a USB disk.
#
# Trade-offs vs iSCSI: simpler to set up, but you are layering a block image on
# top of a file protocol on top of the network. The share MUST be mounted
# before the gadget binds (boot ordering), and you still get only single-writer
# semantics (host is the writer).
#
# PUSHING UPDATES FROM THE NETWORK SIDE: if you regenerate files.img on the NAS,
# the host will NOT see the change until the medium is re-presented. Use the
# forced_eject attribute (mainline kernel) to make the host re-read:
#     echo 1 > <gadget>/functions/mass_storage.0/lun.0/forced_eject
# then write the new path back into .../lun.0/file. Or just run `down` then `up`.
#
# Reference: DanBuchan/Networked_USB_Mass_Storage; kernel mass-storage docs.
# NOT run end-to-end in the research container (no USB-OTG hardware there).
# ---------------------------------------------------------------------------
set -euo pipefail

# ----- CONFIG -------------------------------------------------------------
SHARE="//192.168.1.10/usb"          # SMB share (or use NFS in fstab instead)
SHARE_TYPE="cifs"                    # cifs | nfs
MOUNTPOINT="/srv/usb"
CREDS="/etc/usb-share.creds"        # cifs creds file (username=/password=)
IMG="${MOUNTPOINT}/files.img"
IMG_SIZE_MB=4096                     # only used when creating a fresh image
GADGET=/sys/kernel/config/usb_gadget/netusb
# --------------------------------------------------------------------------

require_root() { [ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }; }

mount_share() {
  mkdir -p "${MOUNTPOINT}"
  if ! mountpoint -q "${MOUNTPOINT}"; then
    if [ "${SHARE_TYPE}" = "cifs" ]; then
      mount -t cifs "${SHARE}" "${MOUNTPOINT}" -o "credentials=${CREDS},vers=3.1.1,nofail"
    else
      mount -t nfs "${SHARE}" "${MOUNTPOINT}" -o "nofail,_netdev"
    fi
  fi
}

ensure_image() {
  if [ ! -f "${IMG}" ]; then
    echo "Creating ${IMG} (${IMG_SIZE_MB} MB) and a FAT32 filesystem..."
    dd if=/dev/zero of="${IMG}" bs=1M count="${IMG_SIZE_MB}" status=progress
    mkfs.vfat "${IMG}"          # FAT32 = max host compatibility; use exFAT/NTFS as needed
  fi
}

create_gadget() {
  modprobe libcomposite; modprobe dwc2 2>/dev/null || true
  mkdir -p "${GADGET}"
  echo 0x1d6b > "${GADGET}/idVendor"
  echo 0x0104 > "${GADGET}/idProduct"
  echo 0x0200 > "${GADGET}/bcdUSB"
  mkdir -p "${GADGET}/strings/0x409"
  echo "netusb0001"         > "${GADGET}/strings/0x409/serialnumber"
  echo "DIY"                > "${GADGET}/strings/0x409/manufacturer"
  echo "Network USB Drive"  > "${GADGET}/strings/0x409/product"
  mkdir -p "${GADGET}/functions/mass_storage.0"
  echo 1          > "${GADGET}/functions/mass_storage.0/lun.0/removable"
  echo 0          > "${GADGET}/functions/mass_storage.0/lun.0/cdrom"
  echo "${IMG}"   > "${GADGET}/functions/mass_storage.0/lun.0/file"
  mkdir -p "${GADGET}/configs/c.1/strings/0x409"
  echo "mass storage" > "${GADGET}/configs/c.1/strings/0x409/configuration"
  echo 250 > "${GADGET}/configs/c.1/MaxPower"
  ln -sf "${GADGET}/functions/mass_storage.0" "${GADGET}/configs/c.1/"
  ls /sys/class/udc | head -n1 > "${GADGET}/UDC"
  echo "Exporting ${IMG} as USB Mass Storage."
}

teardown() {
  echo "" > "${GADGET}/UDC" 2>/dev/null || true
  rm -f "${GADGET}/configs/c.1/mass_storage.0" 2>/dev/null || true
  rmdir "${GADGET}/configs/c.1/strings/0x409" "${GADGET}/configs/c.1" 2>/dev/null || true
  rmdir "${GADGET}/functions/mass_storage.0" "${GADGET}/strings/0x409" "${GADGET}" 2>/dev/null || true
  echo "Gadget removed (share left mounted)."
}

case "${1:-up}" in
  up)   require_root; mount_share; ensure_image; create_gadget ;;
  down) require_root; teardown ;;
  *)    echo "Usage: $0 [up|down]" >&2; exit 1 ;;
esac
