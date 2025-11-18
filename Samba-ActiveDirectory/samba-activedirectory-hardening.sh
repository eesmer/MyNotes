#!/bin/bash

#------------------------------------------------------------------------------------
# Samba Active Directory Hardening
# This script, disables or removes non-essential Active Directory settings in Samba configuration.
# Contains AD related and best practices.
#------------------------------------------------------------------------------------
# Please take a backup and trying do not apply without understanding the configuration in each line.
# This script makes security changes to the Samba Active Directory configuration.
# Please backup, test and apply.
# The script must run on the Samba Active Directory Domain Controller.
#------------------------------------------------------------------------------------
# This script has been tested only on DebianDC installations and is tailored to DebianDC configurations.
# DebianDC makes these settings by default.
# https://github.com/eesmer/DebianDC
# USAGE:
# wget https://raw.githubusercontent.com/eesmer/MyNotes/refs/heads/main/HelperScripts/SambaAD/samba-activedirectory-hardening.sh
# bash  samba-activedirectory-hardening.sh
#------------------------------------------------------------------------------------

# Disable printer
sed -i '/global/a\ \tprinting = bsd' /etc/samba/smb.conf
sed -i '/global/a\ \tdisable spoolss = yes' /etc/samba/smb.conf
sed -i '/global/a\ \tload printers = no' /etc/samba/smb.conf
sed -i '/global/a\ \tprintcap name = /dev/null' /etc/samba/smb.conf

# Turn off NTLMv1
sed -i '/global/a\ \tntlm auth = mschapv2-and-ntlmv2-only' /etc/samba/smb.conf
