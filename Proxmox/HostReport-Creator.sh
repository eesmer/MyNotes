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

