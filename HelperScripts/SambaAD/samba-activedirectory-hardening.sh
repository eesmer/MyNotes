#!/bin/bash

#------------------------------------------------------------------------------------
# This script makes security changes to the Samba Active Directory configuration.
# Please backup, test and apply.
#
# The script must run on the Samba Active Directory Domain Controller.
#------------------------------------------------------------------------------------
# This script has been tested only on DebianDC installations and is tailored to DebianDC configurations.
# DebianDC makes these settings by default.
# https://github.com/eesmer/DebianDC
#------------------------------------------------------------------------------------

# Disable printer
sed -i '/global/a\ \tprinting = bsd' /etc/samba/smb.conf
sed -i '/global/a\ \tdisable spoolss = yes' /etc/samba/smb.conf
sed -i '/global/a\ \tload printers = no' /etc/samba/smb.conf
sed -i '/global/a\ \tprintcap name = /dev/null' /etc/samba/smb.conf

# Turn off NTLMv1
sed -i '/global/a\ \tntlm auth = mschapv2-and-ntlmv2-only' /etc/samba/smb.conf
