#!/bin/bash
set -euo pipefail
set -o errtrace
trap 'ec=$?; echo "[!] Hata ($ec): ${BASH_SOURCE[0]}:${BASH_LINENO[0]}: $(printf "%q" "$BASH_COMMAND")" >&2' ERR

export DEBIAN_FRONTEND=noninteractive

HOSTNAME="erkdebian"
TIMEZONE="Europe/Istanbul"
MYUSER="erkan"
UPDATE_REPORT="/tmp/dpkg-conffile-report.$(date +%F_%H%M%S).txt"

hostnamectl set-hostname "$HOSTNAME"
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
chmod 644 /etc/apt/sources.list

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

cat >/etc/apt/preferences.d/99-backports <<'EOF'
Package: *
Pin: release n=trixie-backports
Pin-Priority: 100
EOF

mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99-options <<'EOF'
APT::Install-Recommends "true";
APT::Install-Suggests "false";
Acquire::Retries "3";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

apt-get update && apt-get -y full-upgrade && apt-get -y autoremove --purge && apt-get -y autoclean

echo "[i] Conffile diff scan starting.." | tee "$UPDATE_REPORT"
printf "NEW_FILE\tORIGINAL\tPACKAGE\tUNITS(owned-by-pkg)\n" | tee -a "$UPDATE_REPORT"

# This block finds packages and services that have not been applied to the confold definition but have been modified in the config file.
# We check with the following example:
# diff -u /etc/ssh/sshd_config /etc/ssh/sshd_config.dpkg-dist | less

mapfile -d '' FILES < <(
  find /etc -type f \
    \( -name '*.dpkg-dist' -o -name '*.dpkg-new' -o -name '*.dpkg-old' \
       -o -name '*.ucf-dist' -o -name '*.ucf-new' -o -name '*.ucf-old' \) \
    -print0 | sort -z
)

if ((${#FILES[@]}==0)); then
  echo "[i] No dpkg/ucf conffile copies found." | tee -a "$UPDATE_REPORT"
else
  for F in "${FILES[@]}"; do
    base="${F%.dpkg-dist}"; base="${base%.dpkg-new}"; base="${base%.dpkg-old}"
    base="${base%.ucf-dist}"; base="${base%.ucf-new}"; base="${base%.ucf-old}"

    pkg="$(dpkg -S "$base" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
    [[ -z "${pkg:-}" ]] && pkg="(unknown/local)"

    units="$(dpkg -L "$pkg" 2>/dev/null | grep -E '\.(service|socket|timer)$' || true)"
    units_names="$( [ -n "$units" ] && basename -a $units 2>/dev/null | paste -sd, - || echo "-" )"

    printf "%s\t%s\t%s\t%s\n" "$F" "$base" "$pkg" "$units_names" | tee -a "$UPDATE_REPORT"
  done
fi

echo "[i] Report: $UPDATE_REPORT"
