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

echo "== ZFS Info  =="
zfs list -r -o name,used,avail,refer,mountpoint,compression,dedup
echo $NEWLINE

echo "== Logical Volume Info  =="
lvs -o vg_name,lv_name,lv_size,lv_attr --noheadings --separator "     "
echo $NEWLINE

echo "== Volume Group Info  =="
vgs -o vg_name,vg_size,vg_free,lv_count,pv_count --noheadings --separator "  "
echo $NEWLINE
echo $BARLINE
echo $NEWLINE

echo $BARLINE
echo "=== DISK INFO & USAGE ==="
df -lh
echo $NEWLINE
echo "== Disk IO Analysis =="
iostat -xz 5 2
echo $NEWLINE
echo $BARLINE
echo $NEWLINE

echo $BARLINE
echo "=== CLUSTER INFO ==="
pvecm status
echo $NEWLINE
pvecm nodes
echo $NEWLINE

echo $BARLINE
echo "=== VM/CT INFO ==="
qm list
echo $NEWLINE
pct list
echo $NEWLINE

