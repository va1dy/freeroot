#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
ARCH=$(uname -m)
MAX_RETRIES=5
TIMEOUT=5

# Определяем архитектуру
if [ "$ARCH" = "x86_64" ]; then
    ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
    ARCH_ALT=arm64
else
    echo "Unsupported CPU architecture: $ARCH"
    exit 1
fi

echo "#######################################################################################"
echo "#"
echo "#                              Ubuntu FreeRoot 24.04 Server installer"
echo "#"
echo "#######################################################################################"

ROOTFS_FILE="$ROOTFS_DIR/rootfs.tar.gz"
ROOTFS_URL="http://cdimage.ubuntu.com/ubuntu/releases/24.04/release/ubuntu-24.04.3-server-amd64.tar.gz"

# Всегда скачиваем rootfs заново
echo "Downloading Ubuntu Server rootfs..."
wget --tries=$MAX_RETRIES --timeout=$TIMEOUT --no-hsts -O "$ROOTFS_FILE" "$ROOTFS_URL" || {
    echo "Failed to download rootfs"
    exit 1
}

# Чистим старый rootfs перед распаковкой
echo "Extracting rootfs..."
rm -rf "$ROOTFS_DIR/bin" "$ROOTFS_DIR/etc" "$ROOTFS_DIR/lib" "$ROOTFS_DIR/usr" "$ROOTFS_DIR/sbin" "$ROOTFS_DIR/tmp" 2>/dev/null
mkdir -p "$ROOTFS_DIR"
tar -xf "$ROOTFS_FILE" -C "$ROOTFS_DIR" || {
    echo "Failed to extract rootfs"
    exit 1
}

# Скачиваем proot
PROOT_FILE="$ROOTFS_DIR/usr/local/bin/proot"
mkdir -p "$ROOTFS_DIR/usr/local/bin"
echo "Downloading proot binary..."
wget --tries=$MAX_RETRIES --timeout=$TIMEOUT --no-hsts -O "$PROOT_FILE" \
"https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}" || {
    echo "Failed to download proot"
    exit 1
}
chmod 755 "$PROOT_FILE"

# Проверяем наличие /bin/sh и создаём симлинк, если нет
if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    if [ -f "$ROOTFS_DIR/bin/bash" ]; then
        ln -sf bash "$ROOTFS_DIR/bin/sh"
    else
        echo "Error: /bin/bash not found in rootfs"
        exit 1
    fi
fi

# resolv.conf
mkdir -p "$ROOTFS_DIR/etc"
echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" > "$ROOTFS_DIR/etc/resolv.conf"

# Цвета для вывода
CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
    echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
    echo -e ""
    echo -e "           ${CYAN}-----> Ubuntu Server Installed ! <----${RESET_COLOR}"
}

clear
display_gg

# Запуск proot с systemd
"$PROOT_FILE" \
  --rootfs="$ROOTFS_DIR" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b "$ROOTFS_DIR/etc/resolv.conf" --kill-on-exit
