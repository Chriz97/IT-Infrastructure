#!/usr/bin/env bash
#
# setup-nfs-server.sh
# Configure an NFS server on Oracle Linux
#
# Share path: /srv/nfs/share
# Client:     192.168.0.8
#

set -euo pipefail

SHARE_DIR="/srv/nfs/share"
CLIENT_IP="192.168.0.8"
EXPORTS_FILE="/etc/exports"

echo "▶ Installing NFS utilities..."
sudo dnf install -y nfs-utils

echo "▶ Enabling and starting NFS services..."
sudo systemctl enable --now rpcbind nfs-server

echo "▶ Creating NFS share directory..."
sudo mkdir -p "$SHARE_DIR"

echo "▶ Setting permissions on share..."
sudo chown -R nobody:nobody "$SHARE_DIR"
sudo chmod 777 "$SHARE_DIR"

EXPORT_LINE="$SHARE_DIR $CLIENT_IP(rw,sync,no_root_squash,no_subtree_check)"

echo "▶ Configuring /etc/exports..."
if ! grep -Fxq "$EXPORT_LINE" "$EXPORTS_FILE"; then
    echo "$EXPORT_LINE" | sudo tee -a "$EXPORTS_FILE"
else
    echo "✔ Export already exists"
fi

echo "▶ Applying NFS exports..."
sudo exportfs -ra

echo "▶ Restarting NFS server..."
sudo systemctl restart nfs-server

echo "▶ Verifying exports..."
sudo exportfs -v

echo "✔ NFS share successfully configured!"
