#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
max_retries=50
timeout=30
ARCH=$(uname -m)

# Определяем архитектуру
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}\n"
  exit 1
fi

# Установка Ubuntu
if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "#######################################################################################"
  echo "#"
  echo "#                                      Ubuntu 24.04 INSTALLER"
  echo "#                                     by va1dy(foxytouxxx fork)"
  echo "#"
  echo "#######################################################################################"

  read -p "Do you want to install Ubuntu? (YES/no): " install_ubuntu
fi

case $install_ubuntu in
  [yY][eE][sS])
    if [ ! -f /tmp/rootfs.tar.gz ]; then
      echo "Downloading Ubuntu 24.04 for architecture: $ARCH_ALT ..."
      wget -v --tries=$max_retries --timeout=$timeout -O /tmp/rootfs.tar.gz \
        "http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-${ARCH_ALT}.tar.gz"
      if [ $? -ne 0 ]; then
        echo "Failed to download Ubuntu. Exiting."
        exit 1
      fi
    fi

    echo "Extracting rootfs..."
    tar -xf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
    ;;
  *)
    echo "Skipping Ubuntu installation."
    ;;
esac

# Создаём рабочую директорию /root
mkdir -p $ROOTFS_DIR/root

# Проверяем наличие /bin/sh
if [ ! -f $ROOTFS_DIR/bin/sh ]; then
  echo "Creating symlink /bin/sh -> /bin/bash"
  ln -s /bin/bash $ROOTFS_DIR/bin/sh
fi

# Установка proot
if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir -p $ROOTFS_DIR/usr/local/bin
  PROOT_URL="https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"

  echo "Downloading proot..."
  wget --tries=$max_retries --timeout=$timeout -O $ROOTFS_DIR/usr/local/bin/proot "$PROOT_URL"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
    rm -f $ROOTFS_DIR/usr/local/bin/proot
    wget --tries=$max_retries --timeout=$timeout -O $ROOTFS_DIR/usr/local/bin/proot "$PROOT_URL"
    sleep 1
  done

  chmod 755 $ROOTFS_DIR/usr/local/bin/proot
fi

# Настройка resolv.conf
if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir -p $ROOTFS_DIR/etc
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > ${ROOTFS_DIR}/etc/resolv.conf
  rm -rf /tmp/rootfs.tar.gz /tmp/sbin
  touch $ROOTFS_DIR/.installed
fi

# Цвета для вывода
CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Ubuntu 24.04 installed ! <----${RESET_COLOR}"
}

clear
display_gg

# Запуск proot с корректным рабочим каталогом и shell
$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="$ROOTFS_DIR" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf \
  /bin/bash --login
