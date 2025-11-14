#!/bin/bash

# --------------------------------------------------
# This script for libvirt host on Debian 13
# - Installs the necessary packages
# - Sets up a virtual network
# - Sets up firewall settings
# --------------------------------------------------

set -e

#------------------
# Color Codes
#------------------
SUCCESS='\033[0;32m' #GREEN
ERROR='\033[0;31m'   #RED
INFO='\033[0;36m'    #CYAN
WARNING='\033[0;33m' #YELLOW
NC='\033[0m'         #NoColor

function handle_error {
    local last_command="$BASH_COMMAND"
    local exit_code="$?"
    local line_number="$1"

    echo -e "\n${ERROR}--------------------------------------------------------------${NC}"
    echo -e "${ERROR}ERROR${NC}[Code: ${exit_code}] Stopped!"
    echo -e "${INFO}Line Number:${NC}${line_number}"
    echo -e "${INFO}Last Command:${NC}${last_command}"
    echo -e "${INFO}Description:${NC}${last_command} ${WARNING}command failed.${NOCOL}"
    echo -e "${ERROR}----------------------------------------------------------------${NC}\n"

    exit 1
}

trap 'handle_error $LINENO' ERR

# KVM-OK Test
echo "Host Virtualization Control:"
if kvm-ok; then
    echo "KVM-OK Success"
else
    echo "ERROR: KVM acceleration is not used. Set it via BIOS"
    exit 1
fi

# Install Packages
apt-get update || { echo -e "\nError: Repository update failed. Check your internet connection or repository list."; exit 1; }
apt-get -y install qemu-kvm libvirt-daemon-system libvirt-clients qemu-utils virtinst bridge-utils netfilter-persistent cpu-checker || { echo -e "\nError: Required packages could not be installed"; exit 1; }

systemctl enable --now libvirtd

# Virtual NW Config
virsh net-destroy default 2>/dev/null
virsh net-undefine default 2>/dev/null

NETWORK_BR1="/tmp/network-br1.xml"
cat << EOF > "$NETWORK_BR1"
<network>
<name>br1-net</name>
<bridge name='br1'/>
<forward mode='nat'/>
<ip address='10.1.1.1' netmask='255.255.255.0'>
<dhcp start='10.1.1.100' end='10.1.1.200'/>
</ip>
</network>
EOF

virsh net-define "$NETWORK_BR1"
virsh net-start br1-net
virsh net-autostart br1-net

sysctl -w net.ipv4.ip_forward=1
sh -c 'echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf'

exit 1

# -----------------------------
# === USAGE NOTES ===
# -----------------------------

# CREATE VM
# -----------------------------
VM_NAME=DebianDC1
DISK_NAME=DebianDC1
DISK_SIZE=25
ISO_PATH=/home/erkan/Downloads/ISO

virt-install \
    --name $VM_NAME --vcpus 2 --memory 1280 --os-variant debian11 \
    --disk path=/var/lib/libvirt/images/$DISK_NAME.qcow2,size=$DISK_SIZE,bus=virtio,format=qcow2 \
    --network bridge=br1,model=virtio \
    --location $ISO_PATH/debian-13.0.0-amd64-netinst.iso \
    --graphics vnc,listen=0.0.0.0 \
    --console pty,target_type=serial \

