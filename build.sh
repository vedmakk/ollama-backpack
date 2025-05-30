#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --models-path PATH   Path to Ollama models directory (default: /usr/share/ollama/.ollama/models)
  --readme PATH        Path to user README file to embed (default: ./docs/USER-GUIDE.md in current dir)
  --clear-cache        By default, previous build artifacts (cache) are retained to speed up rebuilds; Use this to clear the cache before building (default: false)
  --no-usb             Skip writing the ISO to USB
  -h, --help           Show this help and exit
EOF
}

# Default values
MODELS_PATH="/usr/share/ollama/.ollama/models"
README_PATH="$(realpath ./docs/USER-GUIDE.md)"
NO_USB=false
CLEAR_CACHE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --models-path)
      MODELS_PATH="$2"; shift 2;;
    --readme)
      README_PATH="$2"; shift 2;;
    --clear-cache)
      CLEAR_CACHE=true; shift;;
    --no-usb)
      NO_USB=true; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# Validate parameters
if [[ ! -f "$README_PATH" ]]; then
  echo "Error: README file not found: $README_PATH"; exit 1
fi

# Must run as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root."; exit 1
fi

# Detect architecture
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "amd64" ]]; then
  echo "Warning: Architecture is $ARCH; recommended amd64."
fi

# Determine distribution codename
if command -v lsb_release >/dev/null 2>&1; then
  DISTRO=$(lsb_release -sc)
else
  DISTRO="bookworm"
fi

WORKDIR=$(pwd)
VERSION=$(tr -d '[:space:]' < "$WORKDIR/VERSION")
BUILD_DIR="$WORKDIR/live-build"

if $CLEAR_CACHE; then
  echo "[*] Clearing previous build artifacts..."
  rm -rf "$BUILD_DIR"
else
  echo "[*] Skipping cache clear (use --clear-cache to remove previous build artifacts)"
fi

echo "[*] Installing build dependencies..."
apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap xorriso syslinux-common squashfs-tools curl util-linux lsb-release rsync grub-pc-bin grub-efi-amd64-bin mtools

echo "[*] Setting up build directory..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download Ollama if not already downloaded
mkdir -p config/includes.chroot/tmp/ollama
if [[ -f config/includes.chroot/tmp/ollama/ollama.tgz ]]; then
  echo "[*] Ollama archive already downloaded, skipping. Use --clear-cache to force re-download."
else
  echo "[*] Downloading ollama..."
  curl -L "https://ollama.com/download/ollama-linux-${ARCH}.tgz" -o config/includes.chroot/tmp/ollama/ollama.tgz
fi
# TODO AMD GPU

# Installing Ollama…
echo "[*] Unpacking Ollama and models into the includes tree…"

# 1) Unpack the binary
mkdir -p config/includes.chroot/usr
tar -C config/includes.chroot/usr -xzf config/includes.chroot/tmp/ollama/ollama.tgz

# 2) Copy Ollama models where ollama expects them
if [[ -d "$MODELS_PATH" ]]; then
  echo "[*] Copying all Ollama models from $MODELS_PATH..."
  mkdir -p config/includes.chroot/usr/share/ollama/.ollama/models
  if command -v rsync >/dev/null 2>&1; then
      rsync -ah --info=progress2 "$MODELS_PATH"/ config/includes.chroot/usr/share/ollama/.ollama/models
  else
      echo "[!] rsync is not installed. Falling back to standard copy (no progress bar)..."
      cp -r "$MODELS_PATH"/* config/includes.chroot/usr/share/ollama/.ollama/models
  fi
else
  echo "Warning: Models path not found or empty: $MODELS_PATH"
fi

# 3) Create ollama user and systemd service
echo "[*] Creating ollama system user and systemd unit…"

# 3.1) systemd service file
mkdir -p config/includes.chroot/etc/systemd/system
cat > config/includes.chroot/etc/systemd/system/ollama.service <<'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3

# Pick the target that always comes up on a live system
[Install]
WantedBy=multi-user.target
EOF

# Enable it by default (symlink into target.wants/)
mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
ln -sf ../ollama.service \
       config/includes.chroot/etc/systemd/system/multi-user.target.wants/ollama.service

echo "[*] Configuring live-build (distro: $DISTRO, arch: $ARCH)..."
lb config \
  --mode debian \
  --distribution "$DISTRO" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --architectures "$ARCH" \
  --binary-images iso-hybrid \
  --bootloaders grub-efi syslinux \
  --debian-installer none \

echo "[*] Writing custom package list..."
mkdir -p config/package-lists
cat > config/package-lists/custom.list.chroot <<EOF
nano
vim
gparted
util-linux
e2fsprogs
firmware-linux-free
firmware-linux-nonfree
live-config
xfce4
lightdm
EOF

# Disable network modules (Air-gapped mode)
echo "[*] Blacklisting network modules..."
mkdir -p config/includes.chroot/etc/modprobe.d
cat > config/includes.chroot/etc/modprobe.d/blacklist-network.conf <<EOF
# Disable network modules for airgapped environment
blacklist r8169
blacklist e1000e
blacklist e1000
blacklist r8168
blacklist ath9k
blacklist ath10k_pci
blacklist iwlwifi
blacklist wl
blacklist rtl8xxxu
blacklist brcmfmac
blacklist brcmsmac
EOF

# Air-gapped mode banner
echo "[*] Setting AIRGAPPED MODE banner..."
mkdir -p config/includes.chroot/etc/profile.d
cat > config/includes.chroot/etc/profile.d/airgap.sh <<EOF
#!/bin/sh
echo "==========================================="
echo "         AIRGAPPED MODE ACTIVE            "
echo "==========================================="
EOF
chmod +x config/includes.chroot/etc/profile.d/airgap.sh

# Air-gapped mode MOTD banner
echo "[*] Adding MOTD banner..."
mkdir -p config/includes.chroot/etc
cat > config/includes.chroot/etc/motd <<EOF
!!! AIRGAPPED MODE ACTIVE — NETWORK DISABLED !!!
EOF

# Embedding default user README
echo "[*] Embedding default user README..."
mkdir -p config/includes.chroot/etc/skel/Desktop
cp "$README_PATH" config/includes.chroot/etc/skel/Desktop/README.md

# Auto-login into Desktop
echo "[*] Auto-login into Desktop"
mkdir -p config/includes.chroot/etc/lightdm/lightdm.conf.d
cat > config/includes.chroot/etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=user
autologin-session=xfce
EOF

# Adding hooks for ollama user, file ownership fixes, and graphical target setting...
echo "[*] Adding hooks for file ownership fixes, and graphical target setting..."
mkdir -p config/hooks/live

# Hook that creates the ollama user & adjusts permissions inside chroot
cat > config/hooks/live/10_add_ollama_user.hook.chroot <<'HOOK'
#!/usr/bin/env bash
set -e

# 1) create an unprivileged system account for the daemon
if ! id ollama &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -U -m -d /usr/share/ollama ollama
fi

# 2) give the daemon GPU access if the groups exist
for G in render video; do
    getent group "$G" >/dev/null && usermod -aG "$G" ollama
done

# 3) allow the live user (“user” from live-config) to talk to the daemon
id user &>/dev/null && usermod -aG ollama user || true

# 4) make sure every file under /usr/share/ollama is readable
chown -R ollama:ollama /usr/share/ollama || true
chmod -R a+rX /usr/share/ollama || true
HOOK
chmod +x config/hooks/live/10_add_ollama_user.hook.chroot

# Hook to set graphical target as default (for XFCE)
cat > config/hooks/live/20_set_graphical_target.hook.chroot <<'HOOK'
#!/bin/bash
set -e

# Set graphical target as default
systemctl set-default graphical.target
HOOK
chmod +x config/hooks/live/20_set_graphical_target.hook.chroot

# Hook to fix file ownership
cat > config/hooks/live/99_fix_ownership.hook.chroot <<'HOOK'
#!/bin/bash
set -e
chown -R root:root /usr/share/ollama/.ollama/models
chmod -R a+rX /usr/share/ollama
chown root:root /etc/skel/Desktop/README.md
HOOK
chmod +x config/hooks/live/99_fix_ownership.hook.chroot

# Building the live ISO image...
echo "[*] Building the live ISO image..."
lb build

# Locate the generated ISO...
ISO_FILE=$(find . -maxdepth 1 -type f -name "*.hybrid.iso" -o -name "*.iso" | head -n1)
if [[ -z "$ISO_FILE" ]]; then
  echo "Error: ISO file not found."
  exit 1
fi

# Move ISO to dist directory
OUTPUT_ISO_DIR="$WORKDIR/dist"
mkdir -p "$OUTPUT_ISO_DIR"
OUTPUT_ISO="$OUTPUT_ISO_DIR/ollama-backpack-${VERSION}-${ARCH}.iso"
echo "[*] Moving ISO to $OUTPUT_ISO"
cp -f "$ISO_FILE" "$OUTPUT_ISO"

cd "$WORKDIR"

# Optionally write to USB
if ! $NO_USB; then
  echo "[*] Available block devices:"
  lsblk -dpno NAME,SIZE,MODEL
  read -rp "Enter the USB device path to write (e.g., /dev/sdb): " USB_DEV
  if [[ ! -b "$USB_DEV" ]]; then
    echo "Error: $USB_DEV is not a valid block device."
    exit 1
  fi
  if [[ "$(lsblk -nd -o TYPE "$USB_DEV")" != "disk" ]]; then
    echo "Error: $USB_DEV is not a whole disk device. Please specify the device (e.g., /dev/sdb), not a partition (e.g., /dev/sdb1)."
    exit 1
  fi
  read -rp "All data on $USB_DEV will be destroyed. Type 'yes' to continue: " CONFIRM
  if [[ "$CONFIRM" == "yes" ]]; then
    echo "[*] Writing ISO to $USB_DEV..."
    dd if="$OUTPUT_ISO" of="$USB_DEV" bs=4M status=progress oflag=sync
    sync
    echo "[*] ISO written to $USB_DEV successfully."
  else
    echo "Aborted USB writing."
  fi
else
  echo "[*] Skipping USB writing (--no-usb)."
fi

echo "[*] Build complete. ISO located at $OUTPUT_ISO"
