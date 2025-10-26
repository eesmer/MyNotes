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

