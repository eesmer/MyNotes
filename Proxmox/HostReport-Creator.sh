#!/usr/bin/env bash
set -euo pipefail

#-------------------------------------------------------
# Additional Tools
#-------------------------------------------------------
# apt-get -y install sysstat
# journalctl -p err -r
# dmesg
#-------------------------------------------------------

# DEFINATIONS
BARLINE="-----------------------------------------------------"
NEWLINE=""

DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)
UPTIME=$(uptime | xargs)
REPORT="/var/log/Proxmox_HostReport_${HOSTNAME}_${DATE}.txt"

echo $BARLINE
echo "=== HOST INFO ==="
echo "Hostname: $HOSTNAME"
echo "Uptime: $UPTIME"
echo $BARLINE
echo "== TOP Outputs =="
top -b -n1 | head -n10
echo $NEWLINE

echo $BARLINE
echo "=== PACKAGES VERSION INFO ==="
pveversion
echo $NEWLINE
echo $BARLINE
echo $NEWLINE

echo $BARLINE
echo "=== STORAGE POOLS INFO ==="
pvesm status
echo $NEWLINE

