#!/bin/bash
# Extremely Simple Arch Linux ISO Builder with Calamares
# This script builds a custom Arch ISO with maximum compression and Calamares installer
# HEAVY WORK IN PROGRESS.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Arch Linux ISO Builder with Calamares          ║${NC}"
echo -e "${GREEN}║   Ultra Compressed Edition                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Install required packages
echo -e "${YELLOW}[1/8] Installing required packages...${NC}"
pacman -S --needed --noconfirm archiso git base-devel

# Create working directory
WORK_DIR="$HOME/custom-iso"
BUILD_DIR="$WORK_DIR/build"
OUT_DIR="$WORK_DIR/out"

echo -e "${YELLOW}[2/8] Setting up workspace at $WORK_DIR...${NC}"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"
cd "$WORK_DIR"

# Copy releng profile as base
cp -r /usr/share/archiso/configs/releng "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure profiledef.sh with ULTRA compression
echo -e "${YELLOW}[3/8] Configuring ultra compression (xz with max settings)...${NC}"
cat > profiledef.sh << 'EOF'
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="custom-arch"
iso_label="CUSTOM_ARCH_$(date +%Y%m)"
iso_publisher="Custom Arch ISO"
iso_application="Custom Arch Linux with Calamares"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# ULTRA COMPRESSION: xz with maximum settings
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
)
EOF

# Add essential packages including Calamares
echo -e "${YELLOW}[4/8] Adding packages (including Calamares)...${NC}"
cat >> packages.x86_64 << 'EOF'

# Calamares installer
calamares

# Desktop environment (choose one or add your own)
plasma-meta
sddm
xorg

# Essential tools
networkmanager
firefox
kate
dolphin
konsole

# Compression tools
squashfs-tools
xz

EOF

# Copy current user's themes and dotfiles to ISO
echo -e "${YELLOW}[5/8] Packaging your themes and configurations...${NC}"

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Create user skeleton directory
mkdir -p airootfs/etc/skel

# Copy common config directories
CONFIGS=(".config" ".local/share" ".themes" ".icons" ".fonts" ".bashrc" ".zshrc" ".vimrc")
for config in "${CONFIGS[@]}"; do
    if [ -e "$USER_HOME/$config" ]; then
        echo "  - Copying $config..."
        cp -r "$USER_HOME/$config" airootfs/etc/skel/ 2>/dev/null || true
    fi
done

# Add calamares configuration
mkdir -p airootfs/etc/calamares
cat > airootfs/etc/calamares/settings.conf << 'EOF'
modules-search: [ local ]

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - keyboard
  - localecfg
  - users
  - displaymanager
  - networkcfg
  - hwclock
  - services-systemd
  - bootloader
  - umount
- show:
  - finished

branding: default

prompt-install: true
dont-chroot: false
EOF

# Enable essential services
mkdir -p airootfs/etc/systemd/system/multi-user.target.wants
mkdir -p airootfs/etc/systemd/system/graphical.target.wants

# NetworkManager
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service

# Display manager (SDDM)
ln -sf /usr/lib/systemd/system/sddm.service \
    airootfs/etc/systemd/system/graphical.target.wants/sddm.service

# Create auto-start for Calamares
mkdir -p airootfs/etc/xdg/autostart
cat > airootfs/etc/xdg/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Calamares Installer
Exec=sudo -E calamares
Icon=calamares
Terminal=false
Categories=System;
X-KDE-autostart-after=panel
EOF

# Set up sudo for calamares
mkdir -p airootfs/etc/sudoers.d
cat > airootfs/etc/sudoers.d/calamares << 'EOF'
%wheel ALL=(ALL) NOPASSWD: /usr/bin/calamares
EOF
chmod 440 airootfs/etc/sudoers.d/calamares

# Build the ISO
echo -e "${YELLOW}[6/8] Building ISO (this will take a while due to ultra compression)...${NC}"
mkarchiso -v -w "$WORK_DIR/work" -o "$OUT_DIR" "$BUILD_DIR"

# Find the generated ISO
ISO_FILE=$(find "$OUT_DIR" -name "*.iso" | head -n 1)

if [ -f "$ISO_FILE" ]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    echo -e "${GREEN}[7/8] ✓ ISO built successfully!${NC}"
    echo -e "${GREEN}      Location: $ISO_FILE${NC}"
    echo -e "${GREEN}      Size: $ISO_SIZE (ultra compressed)${NC}"
    
    # Create a summary file
    cat > "$OUT_DIR/README.txt" << EOF
Custom Arch Linux ISO with Calamares
=====================================

Build Date: $(date)
ISO File: $(basename "$ISO_FILE")
Size: $ISO_SIZE

Features:
- Ultra compressed with xz (maximum compression)
- Calamares graphical installer
- All your themes and configurations included
- Desktop environment pre-installed
- NetworkManager enabled
- Auto-launches Calamares on boot

To use:
1. Write this ISO to a USB drive with:
   sudo dd if=$ISO_FILE of=/dev/sdX bs=4M status=progress
   (Replace /dev/sdX with your USB device)

2. Boot from the USB drive
3. Calamares installer will start automatically
4. Follow the installation wizard

Your themes and configurations from /etc/skel will be
copied to new user accounts created during installation.

EOF

    echo -e "${GREEN}[8/8] ✓ Summary written to: $OUT_DIR/README.txt${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ISO BUILD COMPLETE!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "To write to USB: ${YELLOW}sudo dd if=$ISO_FILE of=/dev/sdX bs=4M status=progress${NC}"
    echo -e "To test in VM:   ${YELLOW}qemu-system-x86_64 -enable-kvm -m 2048 -cdrom $ISO_FILE${NC}"
    
else
    echo -e "${RED}ERROR: ISO file not found in $OUT_DIR${NC}"
    exit 1
fi
