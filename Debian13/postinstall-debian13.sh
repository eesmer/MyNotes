#!/bin/bash
set -euo pipefail
set -o errtrace
trap 'ec=$?; echo "[!] Hata ($ec): ${BASH_SOURCE[0]}:${BASH_LINENO[0]}: $(printf "%q" "$BASH_COMMAND")" >&2' ERR

export DEBIAN_FRONTEND=noninteractive

HOSTNAME="erkdebian"
TIMEZONE="Europe/Istanbul"
MYUSER="erkan"
REPO="deb http://deb.debian.org" #deb http://ftp2.deb.debian.org

hostnamectl set-hostname "$HOSTNAME"
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

mkdir -p /etc/systemd/timesyncd.conf.d
tee /etc/systemd/timesyncd.conf.d/timesync_custom.conf > /dev/null <<'EOF'
[Time]
NTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org
FallbackNTP=time.google.com pool.ntp.org
EOF
systemctl restart systemd-timesyncd

apt-get update
apt-get install -y locales
sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^# *\(tr_TR.UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_TIME=tr_TR.UTF-8

cat > /etc/apt/sources.list <<'EOF'
$REPO/debian trixie main contrib non-free-firmware
$REPO/debian trixie-updates main contrib non-free-firmware
$REPO/debian-security trixie-security main contrib non-free-firmware
$REPO/debian trixie-backports main contrib non-free-firmware
EOF
chmod 644 /etc/apt/sources.list

cat >/etc/apt/preferences.d/99-backports <<'EOF'
Package: *
Pin: release n=trixie-backports
Pin-Priority: 100
EOF

mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99options <<'EOF'
APT::Install-Recommends "true";
APT::Install-Suggests "false";
Acquire::Retries "3";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

