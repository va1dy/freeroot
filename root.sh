#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
max_retries=50
timeout=30
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
else
  printf "Unsupported CPU architecture: ${ARCH}\n"
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
      echo "Downloading Ubuntu 24.04 (rootfs WSL)..."
      wget -v --tries=$max_retries --timeout=$timeout -O /tmp/rootfs.tar.gz \
        "https://cloud-images.ubuntu.com/releases/mantic/release/ubuntu-23.10-server-cloudimg-amd64.tar.gz"
      if [ $? -ne 0 ]; then
        echo "Failed to download Ubuntu. Exiting."
        exit 1
      fi
    fi

    echo "Extracting rootfs..."
    mkdir -p $ROOTFS_DIR
    # Игнорируем ошибки создания устройств
    tar --numeric-owner --no-same-owner --no-same-permissions --warning=no-dev -xzf /tmp/rootfs.tar.gz -C $ROOTFS_DIR || true
    ;;
  n|*)
    echo "Skipping Ubuntu installation."
    ;;
esac

mkdir -p $ROOTFS_DIR/root

# Проверка /bin/bash
if [ ! -f $ROOTFS_DIR/bin/bash ]; then
    mkdir -p $ROOTFS_DIR/bin
    if [ -f $ROOTFS_DIR/usr/bin/bash ]; then
        ln -s /usr/bin/bash $ROOTFS_DIR/bin/bash
    else
        echo "[ERROR] Bash не найден в rootfs!"
        exit 1
    fi
fi

# Проверка /bin/sh
if [ ! -f $ROOTFS_DIR/bin/sh ]; then
    ln -s /bin/bash $ROOTFS_DIR/bin/sh
fi

# Установка proot и зависимостей, если ещё не установлено
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

  # Настройка сети
  mkdir -p $ROOTFS_DIR/etc
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > ${ROOTFS_DIR}/etc/resolv.conf

  # Установка dbus и supervisor внутри proot
  $ROOTFS_DIR/usr/local/bin/proot --rootfs="$ROOTFS_DIR" -0 -w "/root" /bin/bash -c "\
    apt update && apt install -y dbus supervisor openssh-server || true"

  # Создание конфигурации supervisor для демонов
  mkdir -p $ROOTFS_DIR/etc/supervisor/conf.d
  cat <<EOF > $ROOTFS_DIR/etc/supervisor/conf.d/default.conf
[supervisord]
nodaemon=true

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
EOF

  rm -rf /tmp/rootfs.tar.gz /tmp/sbin
  touch $ROOTFS_DIR/.installed
fi

CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Ubuntu 24.04 installed! <----${RESET_COLOR}"
}

clear
display_gg

# Запуск proot с supervisor для поднятия демонов
$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="$ROOTFS_DIR" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf \
  /bin/bash -c "supervisord -c /etc/supervisor/conf.d/default.conf"
