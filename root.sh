#!/bin/sh

ROOTFS_DIR=$(pwd)
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
else
  echo "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "#######################################################################################"
  echo "#"
  echo "#                                      Ubuntu 24.04 INSTALLER"
  echo "#                                     by va1dy(foxytouxxx fork)"
  echo "#"
  echo "#######################################################################################"

  read -p "Do you want to install Ubuntu? (y/n): " install_ubuntu
  install_ubuntu=$(echo "$install_ubuntu" | tr '[:upper:]' '[:lower:]')
fi

case $install_ubuntu in
  y)
    if [ ! -f /tmp/rootfs.tar.gz ]; then
      echo "Downloading Ubuntu 24.04 with systemd..."
      wget -v --tries=50 --timeout=30 -O /tmp/rootfs.tar.gz \
        "https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz"
      if [ $? -ne 0 ]; then
        echo "Failed to download Ubuntu. Exiting."
        exit 1
      fi
    fi

    echo "Extracting rootfs..."
    mkdir -p $ROOTFS_DIR
    tar -xf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
    ;;
  n|*)
    echo "Skipping Ubuntu installation."
    ;;
esac

mkdir -p $ROOTFS_DIR/root

if [ ! -f $ROOTFS_DIR/bin/sh ]; then
  mkdir -p $ROOTFS_DIR/bin
  echo "Creating symlink /bin/sh -> /bin/bash"
  ln -s /bin/bash $ROOTFS_DIR/bin/sh
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir -p $ROOTFS_DIR/usr/local/bin
  PROOT_URL="https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"

  echo "Downloading proot..."
  wget --tries=50 --timeout=30 -O $ROOTFS_DIR/usr/local/bin/proot "$PROOT_URL"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
    rm -f $ROOTFS_DIR/usr/local/bin/proot
    wget --tries=50 --timeout=30 -O $ROOTFS_DIR/usr/local/bin/proot "$PROOT_URL"
    sleep 1
  done

  chmod 755 $ROOTFS_DIR/usr/local/bin/proot
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir -p $ROOTFS_DIR/etc
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > ${ROOTFS_DIR}/etc/resolv.conf
  rm -rf /tmp/rootfs.tar.gz /tmp/sbin
  touch $ROOTFS_DIR/.installed
fi

CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Ubuntu 24.04 installed with systemd! <----${RESET_COLOR}"
}

clear
display_gg

$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="$ROOTFS_DIR" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf \
  /bin/bash --login
