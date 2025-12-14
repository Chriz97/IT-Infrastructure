#!/usr/bin/env bash
# nfs-toggle.sh
# Mount/unmount NFS share 192.168.0.220:/srv/nfs/share at /mnt/share
# Usage:
#   sudo ./nfs-toggle.sh mount
#   sudo ./nfs-toggle.sh unmount
#   sudo ./nfs-toggle.sh status

set -euo pipefail

SERVER="192.168.0.5"
EXPORT="/srv/nfs/share"
MOUNTPOINT="/mnt/share"
# Tweak options if needed:
OPTS="rw,nfsvers=4.2,hard,intr,noatime,_netdev"

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo $0 $*"
    exit 1
  fi
}

do_status() {
  echo "Share:   ${SERVER}:${EXPORT}"
  echo "Mount to: ${MOUNTPOINT}"
  if mountpoint -q "$MOUNTPOINT"; then
    echo "Status:  MOUNTED"
    mount | grep -E "on ${MOUNTPOINT} type nfs"
  else
    echo "Status:  NOT MOUNTED"
  fi
}

do_mount() {
  need_root "$@"
  mkdir -p "$MOUNTPOINT"
  if mountpoint -q "$MOUNTPOINT"; then
    echo "[INFO] Already mounted at $MOUNTPOINT"
    return
  fi
  echo "[INFO] Mounting ${SERVER}:${EXPORT} -> ${MOUNTPOINT}"
  mount -t nfs -o "$OPTS" "${SERVER}:${EXPORT}" "$MOUNTPOINT"
  echo "[OK] Mounted."
}

do_unmount() {
  need_root "$@"
  if mountpoint -q "$MOUNTPOINT"; then
    echo "[INFO] Unmounting $MOUNTPOINT"
    umount "$MOUNTPOINT"
    echo "[OK] Unmounted."
  else
    echo "[INFO] $MOUNTPOINT is not mounted."
  fi
}

case "${1:-}" in
  mount)   do_mount ;;
  unmount) do_unmount ;;
  status|"") do_status ;;
  *) echo "Usage: $0 {mount|unmount|status}"; exit 2 ;;
esac
