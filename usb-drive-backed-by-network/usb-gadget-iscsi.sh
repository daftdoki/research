#!/usr/bin/env bash
#
# usb-gadget-iscsi.sh
# ---------------------------------------------------------------------------
# Present a network-backed block device (an iSCSI LUN) to a host computer as a
# plain USB Mass Storage drive, using Linux USB gadget mode (libcomposite /
# configfs) on a Raspberry Pi (Zero 2 W, 4, 5, CM4/CM5) or similar dwc2 board.
#
# Data path:   NAS/server iSCSI target  --(Ethernet/Wi-Fi, SCSI blocks)-->
#              Pi open-iscsi initiator -> /dev/sdX -> usb_f_mass_storage ->
#              USB-C OTG port -> host sees a normal USB disk.
#
# Why iSCSI (not NFS/SMB): the mass-storage gadget exports a *block device*.
# iSCSI gives the Pi a real block device whose blocks live on the network, so
# the host's writes are written back with correct block semantics. NFS/SMB are
# file protocols and cannot be fed to the gadget directly (you'd have to put an
# image file on them — see usb-gadget-imagefile.sh).
#
# COHERENCY RULE: the host is the ONLY writer. Do NOT mount the LUN's
# filesystem on the Pi while it is exported. Block protocols have no shared-
# write coherency; two writers = corruption.
#
# Tested against the Linux kernel configfs gadget docs and the
# jwmullally/openwrt-rpi4-iscsi-to-usb-bridge + matt.olan.me piSCSI projects.
# NOT run end-to-end in the research container (no USB-OTG hardware there).
# ---------------------------------------------------------------------------
set -euo pipefail

# ----- CONFIG: edit these -------------------------------------------------
TARGET_IP="192.168.1.10"                       # iSCSI target (NAS) address
TARGET_IQN="iqn.2026-06.com.example:usbdrive"  # target IQN (from the NAS)
VENDOR_ID="0x1d6b"                              # 0x1d6b = Linux Foundation
PRODUCT_ID="0x0104"                             # 0x0104 = Multifunction gadget
SERIAL="netusb0001"
MANUFACTURER="DIY"
PRODUCT="Network USB Drive"
READ_ONLY=0                                     # 1 = present as read-only
REMOVABLE=1                                     # 1 = host sees it as removable
# --------------------------------------------------------------------------

GADGET=/sys/kernel/config/usb_gadget/netusb
UDC_NAME=""

require_root() { [ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }; }

load_modules() {
  modprobe libcomposite
  # On Pi, dwc2 must be in peripheral/OTG mode. Add to /boot/firmware/config.txt:
  #   dtoverlay=dwc2,dr_mode=peripheral
  # and 'dwc2' to /etc/modules, then reboot. We just ensure it is loaded:
  modprobe dwc2 2>/dev/null || true
}

connect_iscsi() {
  # open-iscsi: discover + login. Produces /dev/sdX for the LUN.
  iscsiadm -m discovery -t sendtargets -p "${TARGET_IP}" >/dev/null
  iscsiadm -m node -T "${TARGET_IQN}" -p "${TARGET_IP}" --login
  # Wait for the block device to appear and resolve its /dev path.
  local dev="" tries=0
  while [ -z "${dev}" ] && [ "${tries}" -lt 30 ]; do
    sleep 1; tries=$((tries+1))
    dev=$(lsscsi 2>/dev/null | awk '/disk/ && /'"${TARGET_IP%%.*}"'|IET|LIO/ {print $NF; exit}')
    # Fallback: newest /dev/sd* device.
    [ -z "${dev}" ] && dev=$(ls -1t /dev/sd? 2>/dev/null | head -n1 || true)
  done
  [ -n "${dev}" ] || { echo "iSCSI block device not found." >&2; exit 1; }
  echo "${dev}"
}

create_gadget() {
  local backing="$1"
  mkdir -p "${GADGET}"
  echo "${VENDOR_ID}"  > "${GADGET}/idVendor"
  echo "${PRODUCT_ID}" > "${GADGET}/idProduct"
  echo 0x0200 > "${GADGET}/bcdUSB"      # USB 2.0
  echo 0x0100 > "${GADGET}/bcdDevice"

  mkdir -p "${GADGET}/strings/0x409"
  echo "${SERIAL}"       > "${GADGET}/strings/0x409/serialnumber"
  echo "${MANUFACTURER}" > "${GADGET}/strings/0x409/manufacturer"
  echo "${PRODUCT}"      > "${GADGET}/strings/0x409/product"

  mkdir -p "${GADGET}/functions/mass_storage.0"
  echo "${REMOVABLE}" > "${GADGET}/functions/mass_storage.0/lun.0/removable"
  echo "${READ_ONLY}" > "${GADGET}/functions/mass_storage.0/lun.0/ro"
  echo 0              > "${GADGET}/functions/mass_storage.0/lun.0/cdrom"
  # nofua=1 ignores Force-Unit-Access (faster, but flush carefully on eject).
  echo 1              > "${GADGET}/functions/mass_storage.0/lun.0/nofua"
  echo "${backing}"   > "${GADGET}/functions/mass_storage.0/lun.0/file"

  mkdir -p "${GADGET}/configs/c.1/strings/0x409"
  echo "Config 1: mass storage" > "${GADGET}/configs/c.1/strings/0x409/configuration"
  echo 250 > "${GADGET}/configs/c.1/MaxPower"
  ln -sf "${GADGET}/functions/mass_storage.0" "${GADGET}/configs/c.1/"

  UDC_NAME=$(ls /sys/class/udc | head -n1)
  echo "${UDC_NAME}" > "${GADGET}/UDC"     # bind => the host now sees the disk
  echo "Gadget bound to UDC ${UDC_NAME}, exporting ${backing}"
}

teardown() {
  echo "" > "${GADGET}/UDC" 2>/dev/null || true
  rm -f "${GADGET}/configs/c.1/mass_storage.0" 2>/dev/null || true
  rmdir "${GADGET}/configs/c.1/strings/0x409" 2>/dev/null || true
  rmdir "${GADGET}/configs/c.1" 2>/dev/null || true
  rmdir "${GADGET}/functions/mass_storage.0" 2>/dev/null || true
  rmdir "${GADGET}/strings/0x409" 2>/dev/null || true
  rmdir "${GADGET}" 2>/dev/null || true
  iscsiadm -m node -T "${TARGET_IQN}" -p "${TARGET_IP}" --logout 2>/dev/null || true
  echo "Torn down."
}

case "${1:-up}" in
  up)
    require_root; load_modules
    DEV=$(connect_iscsi)
    echo "Using iSCSI block device: ${DEV}"
    create_gadget "${DEV}"
    ;;
  down) require_root; teardown ;;
  *) echo "Usage: $0 [up|down]" >&2; exit 1 ;;
esac
