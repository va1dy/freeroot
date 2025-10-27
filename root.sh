#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
ARCH=$(uname -m)
MAX_RETRIES=5
TIMEOUT=5

# Определяем архитектуру для скачивания
if [ "$ARCH" = "x86_64" ]; then
    ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
    ARCH_ALT=arm64
else
    echo "Unsupported CPU architecture: $ARCH"
    exit 1
fi

# Проверка rootfs
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
    echo "#######################################################################################"
    echo "#"
    echo "#                              Ubuntu FreeRoot 24.04 installer"
    echo "#"
    echo "#######################################################################################"

    read -p "Do you want to install Ubuntu? (YES/no): " install_ubuntu
fi

case $install_ubuntu in
    [yY][eE][sS])
        ROOTFS_FILE="$ROOTFS_DIR/rootfs.tar.gz"

        if [ ! -f "$ROOTFS_FILE" ]; then
            echo "Downloading Ubuntu rootfs..."
            wget --tries=$MAX_RETRIES --timeout=$TIMEOUT --no-hsts -O "$ROOTFS_FILE" \
            "http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-amd64.tar.gz" || {
                echo "Failed to download rootfs"
                exit 1
            }
        else
            echo "Rootfs already exists, skipping download."
        fi

        echo "Extracting rootfs..."
        tar -xf "$ROOTFS_FILE" -C "$ROOTFS_DIR" || {
            echo "Failed to extract rootfs"
            exit 1
        }
        ;;
    *)
        echo "Skipping Ubuntu installation."
        ;;
esac

# Скачиваем proot
PROOT_FILE="$ROOTFS_DIR/usr/local/bin/proot"
if [ ! -s "$PROOT_FILE" ]; then
    mkdir -p "$ROOTFS_DIR/usr/local/bin"
    echo "Downloading proot binary..."
    wget --tries=$MAX_RETRIES --timeout=$TIMEOUT --no-hsts -O "$PROOT_FILE" \
    "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}" || {
        echo "Failed to download proot"
        exit 1
    }
    chmod 755 "$PROOT_FILE"
fi

# Проверяем наличие /bin/sh в rootfs
if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    if [ -f "$ROOTFS_DIR/bin/bash" ]; then
        ln -s bash "$ROOTFS_DIR/bin/sh"
    else
        echo "Error: /bin/bash not found in rootfs"
        exit 1
    fi
fi

# resolv.conf
if [ ! -e "$ROOTFS_DIR/etc/resolv.conf" ]; then
    mkdir -p "$ROOTFS_DIR/etc"
    echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" > "$ROOTFS_DIR/etc/resolv.conf"
fi

# Пометка, что установка завершена
touch "$ROOTFS_DIR/.installed"

# Цвета для вывода
CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
    echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
    echo -e ""
    echo -e "           ${CYAN}-----> Ubuntu Installed ! <----${RESET_COLOR}"
}

clear
display_gg

# Запуск proot
"$PROOT_FILE" \
  --rootfs="$ROOTFS_DIR" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b "$ROOTFS_DIR/etc/resolv.conf" --kill-on-exit
