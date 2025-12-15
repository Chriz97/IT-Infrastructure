#!/usr/bin/env bash
#
# setup-lvm-mount.sh
# Create and mount an LVM logical volume with persistent fstab entry
#
# WARNING:
# - THIS WILL WIPE THE TARGET DISK
# - DO NOT RUN ON A DISK WITH DATA
#

set -euo pipefail

# ===== CONFIGURATION =====
DISK="/dev/sdb"
VG_NAME="vg_data"
LV_NAME="lv_storage"
LV_SIZE="100%FREE"
MOUNT_POINT="/mnt/storage"
FS_TYPE="xfs"
# =========================

echo "▶ Checking disk exists..."
lsblk "$DISK" > /dev/null

echo "▶ Installing required packages..."
dnf install -y lvm2 util-linux

echo "▶ Creating physical volume..."
pvcreate "$DISK"

echo "▶ Creating volume group..."
vgcreate "$VG_NAME" "$DISK"

echo "▶ Creating logical volume..."
lvcreate -n "$LV_NAME" -l "$LV_SIZE" "$VG_NAME"

LV_PATH="/dev/$VG_NAME/$LV_NAME"

echo "▶ Creating filesystem ($FS_TYPE)..."
mkfs."$FS_TYPE" "$LV_PATH"

echo "▶ Creating mount point..."
mkdir -p "$MOUNT_POINT"

echo "▶ Retrieving UUID..."
UUID=$(blkid -s UUID -o value "$LV_PATH")

echo "▶ Backing up /etc/fstab..."
cp /etc/fstab /etc/fstab.bak.$(date +%F_%T)

echo "▶ Adding fstab entry..."
FSTAB_LINE="UUID=$UUID  $MOUNT_POINT  $FS_TYPE  defaults  0  0"

if ! grep -q "$UUID" /etc/fstab; then
    echo "$FSTAB_LINE" >> /etc/fstab
else
    echo "✔ fstab entry already exists"
fi

echo "▶ Mounting filesystem..."
mount -a

echo "▶ Verifying mount..."
df -h | grep "$MOUNT_POINT"

echo "✔ LVM volume successfully created and mounted!"
