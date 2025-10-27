#!/bin/bash

# --------------------------------------------------
# This script for libvirt host on Debian 13
# - Installs the necessary packages
# - Sets up a virtual network
# - Sets up firewall settings
# --------------------------------------------------

# KVM-OK Test
echo "Host Virtualization Control:"
if kvm-ok; then
    echo "KVM-OK Success"
else
    echo "ERROR: KVM acceleration is not used. Set it via BIOS"
    exit 1
fi

# Install Packages
apt-get update
apt-get -y install qemu-kvm libvirt-daemon-system libvirt-clients qemu-utils virtinst bridge-utils netfilter-persistent cpu-checker

systemctl enable --now libvirtd

# Virtual NW Config
virsh net-destroy default 2>/dev/null
virsh net-undefine default 2>/dev/null

