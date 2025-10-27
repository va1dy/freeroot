#!/bin/sh
set -euo pipefail

ROOTFS_DIR="$(pwd)"
export PATH="$PATH:~/.local/usr/bin"
max_retries=50
timeout=30
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH_ALT=amd64 ;;
  aarch64) ARCH_ALT=arm64 ;;
  *)
    printf "Unsupported CPU architecture: %s\n" "$ARCH" >&2
    exit 1
    ;;
esac

if [ ! -e "${ROOTFS_DIR}/.installed" ]; then
  echo "#######################################################################################"
  echo "#"
  echo "# Ubuntu 24.04 INSTALLER"
  echo "# by va1dy (foxytouxxx fork)"
  echo "#"
  echo "#######################################################################################"
  printf "%s" "Do you want to install Ubuntu? (y/n): "
  # POSIX read
  read -r install_ubuntu
  # lower-case conversion (portable)
  install_ubuntu="$(printf "%s" "$install_ubuntu" | tr '[:upper:]' '[:lower:]')"
fi

case "${install_ubuntu:-n}" in
  y)
    if [ ! -f /tmp/rootfs.tar.gz ]; then
    echo "Downloading Ubuntu 24.04 for architecture: $ARCH_ALT ..."
      URL="https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz"
      # try wget or curl
      if command -v wget >/dev/null 2>&1; then
        wget -v --tries="$max_retries" --timeout="$timeout" -O /tmp/rootfs.tar.gz "$URL"
      elif command -v curl >/dev/null 2>&1; then
        curl -fSL --retry "$max_retries" --max-time "$timeout" -o /tmp/rootfs.tar.gz "$URL"
      else
        printf "Neither wget nor curl found. Install one and retry.\n" >&2
        exit 1
      fi
    fi

    echo "Extracting rootfs..."
    mkdir -p "$ROOTFS_DIR"
    tar -xf /tmp/rootfs.tar.gz -C "$ROOTFS_DIR"
    ;;
  n|*)
    echo "Skipping Ubuntu installation."
    ;;
esac

mkdir -p "$ROOTFS_DIR/root"

if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
  mkdir -p "$ROOTFS_DIR/bin"
  echo "Creating symlink $ROOTFS_DIR/bin/sh -> /bin/bash"
  ln -sf /bin/bash "$ROOTFS_DIR/bin/sh"
fi

if [ ! -e "$ROOTFS_DIR/.installed" ]; then
  mkdir -p "$ROOTFS_DIR/usr/local/bin"

  PROOT_URL="https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"
  PROOT_PATH="$ROOTFS_DIR/usr/local/bin/proot"

  echo "Downloading proot..."
  if command -v wget >/dev/null 2>&1; then
    wget --tries="$max_retries" --timeout="$timeout" -O "$PROOT_PATH" "$PROOT_URL"
  elif command -v curl >/dev/null 2>&1; then
    curl -fSL --retry "$max_retries" --max-time "$timeout" -o "$PROOT_PATH" "$PROOT_URL"
  fi

  # retry until non-empty file (as in original)
  retry_count=0
  while [ ! -s "$PROOT_PATH" ] && [ "$retry_count" -lt "$max_retries" ]; do
    rm -f "$PROOT_PATH"
    if command -v wget >/dev/null 2>&1; then
      wget --tries=1 --timeout="$timeout" -O "$PROOT_PATH" "$PROOT_URL"
    elif command -v curl >/dev/null 2>&1; then
      curl -fSL --max-time "$timeout" -o "$PROOT_PATH" "$PROOT_URL"
    fi
    retry_count=$((retry_count + 1))
    sleep 1
  done

  chmod 755 "$PROOT_PATH"
fi

if [ ! -e "$ROOTFS_DIR/.installed" ]; then
  mkdir -p "$ROOTFS_DIR/etc"
  printf 'nameserver 1.1.1.1\nnameserver 1.0.0.1\n' > "${ROOTFS_DIR}/etc/resolv.conf"
  rm -rf /tmp/rootfs.tar.gz /tmp/sbin || true
  touch "$ROOTFS_DIR/.installed"
fi

# Display message and run proot
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET_COLOR='\033[0m'

display_gg() {
  printf "%b___________________________________________________%b\n" "$WHITE" "$RESET_COLOR"
  printf "\n"
  printf " %b-----> Ubuntu 24.04 installed ! <----%b\n" "$CYAN" "$RESET_COLOR"
}

clear || true
display_gg

# Final proot exec (if proot exists)
if [ -x "$ROOTFS_DIR/usr/local/bin/proot" ]; then
  exec "$ROOTFS_DIR/usr/local/bin/proot" \
    --rootfs="$ROOTFS_DIR" \
    -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf \
    /bin/bash --login
else
  printf "proot was not found or is not executable at: %s\n" "$ROOTFS_DIR/usr/local/bin/proot" >&2
  exit 1
fi
