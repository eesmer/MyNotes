#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

cat >/etc/apt/sources.list <<'EOF'
deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-backports main contrib non-free
deb-src http://deb.debian.org/debian/ bookworm-backports main contrib non-free
EOF

apt-get update -y
apt-get -y dist-upgrade

# PACKAGES
apt-get -y install $(apt search ^firmware- 2> /dev/null | grep ^firmware | grep -v micropython-dl | cut -d "/" -f 1)
apt-get install -y \
  i3 xtrlock thunar zsh fzf \
  vim tmux openssh-server htop \
  feathernotes atril pavucontrol unzip xfce4-terminal freerdp2-x11 vlc feh \
  firefox-esr chromium \
  libreoffice-writer libreoffice-calc libreoffice-impress \
  git ack wget curl rsync dnsutils whois net-tools \
  gnupg2 openvpn
