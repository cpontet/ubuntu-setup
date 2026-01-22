#!/bin/bash
# Linux Surface installation script for Zorin OS 18 / Surface Laptop 3
# Run with: sudo bash install-linux-surface.sh

set -e

echo "=== Linux Surface Installation for Zorin OS 18 ==="
echo "=== Optimized for Surface Laptop 3 ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo" 
   exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}

echo "[1/8] Installing prerequisites..."
apt update
apt install -y wget gnupg2 curl

echo "[2/8] Installing Intel microcode firmware..."
# Required to avoid boot issues on Intel-based Surface devices
apt install -y intel-microcode

echo "[3/8] Adding Linux Surface signing key..."
wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
    | gpg --dearmor | dd of=/etc/apt/trusted.gpg.d/linux-surface.gpg

echo "[4/8] Adding Linux Surface repository..."
echo "deb [arch=amd64] https://pkg.surfacelinux.com/debian release main" \
    > /etc/apt/sources.list.d/linux-surface.list

apt update

echo "[5/8] Installing Linux Surface kernel..."
apt install -y linux-image-surface linux-headers-surface

echo "[6/8] Installing Surface-specific packages..."
# libwacom-surface: Better pen/stylus support
# iptsd: Intel Precise Touch & Stylus Daemon (touchscreen/pen)
apt install -y libwacom-surface iptsd

echo "[7/8] Installing Secure Boot MOK (optional but recommended)..."
# This allows booting with Secure Boot enabled
apt install -y linux-surface-secureboot-mok || echo "Secure boot MOK installation skipped"

echo "[8/8] Updating GRUB..."
update-grub

echo ""
echo "=============================================="
echo "=== Installation complete! ==="
echo "=============================================="
echo ""
echo "IMPORTANT - Next steps:"
echo ""
echo "1. REBOOT your laptop"
echo ""
echo "2. If you have Secure Boot ENABLED:"
echo "   - After reboot, a blue MOK Manager screen will appear"
echo "   - Select 'Enroll MOK' -> 'Continue' -> 'Yes'"
echo "   - Enter password: SURFACE"
echo "   - Select 'Reboot'"
echo ""
echo "3. If Secure Boot gives you trouble, you can disable it:"
echo "   - Shutdown completely"
echo "   - Hold Volume Up + Power to enter UEFI"
echo "   - Go to Security -> Secure Boot -> Disable"
echo ""
echo "4. After reboot, verify the Surface kernel is running:"
echo "   uname -r"
echo "   (should show something like: 6.x.x-surface)"
echo ""
echo "=============================================="
echo "Surface Laptop 3 - What should work:"
echo "=============================================="
echo "✓ Keyboard"
echo "✓ Touchpad (with gestures)"
echo "✓ Touchscreen"
echo "✓ Pen/Stylus"
echo "✓ WiFi"
echo "✓ Bluetooth"
echo "✓ Battery reporting"
echo "✓ Suspend/Resume"
echo "✓ Screen brightness"
echo ""
echo "=============================================="
echo "Power management recommendation:"
echo "=============================================="
echo "Do NOT use TLP - it can cause performance issues on Surface devices."
echo "Instead, consider using 'auto-cpufreq' for battery optimization:"
echo "  sudo apt install auto-cpufreq"
echo "  sudo auto-cpufreq --install"
echo ""