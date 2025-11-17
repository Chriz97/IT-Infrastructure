#!/bin/bash
# gpu-info.sh - Quick NVIDIA driver/module diagnostic

echo "=== GPU Info (lspci) ==="
lspci -nnk | grep -A 3 -E "VGA|3D|Display"

echo -e "\n=== Loaded NVIDIA/Nouveau Modules (lsmod) ==="
lsmod | grep -E "nvidia|nouveau" || echo "No NVIDIA/Nouveau modules loaded."

echo -e "\n=== NVIDIA Kernel Module Info (modinfo) ==="
modinfo nvidia | grep -E "filename|version|license|srcversion" 2>/dev/null || echo "NVIDIA module not found."

echo -e "\n=== Installed NVIDIA Packages (pacman) ==="
pacman -Qs nvidia | grep local

echo -e "\n=== DRM Devices ==="
ls -l /dev/dri/by-path/ 2>/dev/null || echo "No DRM devices found."

echo -e "\n=== Done. ==="
