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

echo $BARLINE
echo "=== VMs USING THE MOST CPU ==="
pvesh get /cluster/resources --type vm \
  | awk '
    /^{/ {rec=$0}
    /}/  {print rec $0}
  ' 2>/dev/null | \
  sed 's/[{}",]//g;s/:/ /g' | \
  awk '
    {for(i=1;i<=NF;i++){ if($i=="vmid") vmid=$(i+1); if($i=="name") name=$(i+1); if($i=="cpu") cpu=$(i+1); if($i=="mem") mem=$(i+1); if($i=="maxmem") maxmem=$(i+1)}
     if(vmid!=""){printf "%6s %-25s %8.2f %%CPU  %8.2f %%MEM\n", vmid, name, cpu*100, (maxmem>0? (mem/maxmem*100):0)}
     vmid=name=cpu=mem=maxmem=""
    }' | sort -k4 -nr | head -n "10"
echo $NEWLINE

echo $BARLINE
echo "=== VMs USING THE MOST RAM ==="
pvesh get /cluster/resources --type vm \
  | awk '
    /^{/ {rec=$0}
    /}/  {print rec $0}
  ' 2>/dev/null | \
  sed 's/[{}",]//g;s/:/ /g' | \
  awk '
    {for(i=1;i<=NF;i++){ if($i=="vmid") vmid=$(i+1); if($i=="name") name=$(i+1); if($i=="mem") mem=$(i+1); if($i=="maxmem") maxmem=$(i+1)}
     if(vmid!=""){printf "%6s %-25s %8.2f %%MEM\n", vmid, name, (maxmem>0? (mem/maxmem*100):0)}
     vmid=name=mem=maxmem=""
    }' | sort -k4 -nr | head -n "10"
echo $NEWLINE

echo $BARLINE
echo "=== VM ANALYSIS ==="
pvesh get /cluster/resources --type vm 2>/dev/null
pvesh get /cluster/resources --type vm 2>/dev/null > vm_analysis.txt
pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | jq '
map(
select(.type == "qemu") |
.diskread /= 1073741824 |
.diskwrite /= 1073741824 |
.netin /= 1073741824 |
.netout /= 1073741824 |
.maxdisk /= 1073741824 |
.maxmem /= 1073741824 |
.mem /= 1073741824 |
.uptime /= 86400
)
' > vm_analysis.json

echo $NEWLINE
echo $BARLINE
echo "== Log Summary  =="
echo "Authentication Fail Log Records"
journalctl -p err -r | grep "authentication failure"
echo $NEWLINE
echo "Connection Time Out Log Records"
journalctl -p err -r -o cat | grep "connection timed out" | sort | uniq
echo $BARLINE

echo "Finish - $DATE"
echo -e

