#!/bin/bash

# Color Codes
MAGENTA="tput setaf 1"
GREEN="tput setaf 2"
YELLOW="tput setaf 3"
DGREEN="tput setaf 4"
CYAN="tput setaf 6"
WHITE="tput setaf 7"
GRAY="tput setaf 8"
RED="tput setaf 9"
BLUE="tput setaf 12"
NOCOL="tput sgr0"
BOLD="tput bold"

UPDATE_CONTROL() {
    $GREEN
    echo "Internet and repository access is controlled"
    $NOCOL
    UPDATE_OUTPUT=$(apt update 2>&1)
    if echo "$UPDATE_OUTPUT" | grep -qE "(Failed to fetch|Temporary failure resolving|Could not resolve|Some index files failed to download)"; then
        $RED
        echo "Some errors occurred during apt update. Please check internet or repository access."
        echo "$UPDATE_OUTPUT" #> $LOGFILE
        $NOCOL
        exit 1
    fi
}

CHECKRUN_ROOT() {
    $GREEN
    echo "Checking root user session"
    $NOCOL
    if ! [[ $EUID -eq 0 ]]; then
	    $RED
	    echo "This script must be run with root user"
	    $NOCOL
	    exit 1
    fi
}

CHECK_COMMANDS() {
	$GREEN
	echo "Checking Samba AD Installation"
	$NOCOL
	if [[ ! -x $(command -v samba-tool) ]]; then
		$RED
		echo "samba-tool command not found. You must run this script on the DC machine"
		$NOCOL
		exit 1
	fi
	
	if ! [ -x "$(command -v nmap)" ]; then
		apt-get -y install nmap
	fi
}

REPORTING() {
	$GREEN
	echo "Samba AD Report is being Generated"
	$NOCOL
	SERVERNAME=$(cat /etc/hostname)
	SERVERIP=$(ip r |grep link |grep src |cut -d'/' -f2 |cut -d'c' -f3 |cut -d' ' -f2)
	DOMAINNAME=$(cat /etc/samba/smb.conf | grep "realm" | cut -d "=" -f2 | xargs)
	KERBEROSNAME=$(cat /etc/krb5.conf | grep default_realm | cut -d"=" -f2 | xargs)
	SERVERROLE=$(cat /etc/samba/smb.conf | grep "server role" | cut -d "=" -f2 | xargs)
	FORESTLEVEL=$(samba-tool domain level show | grep "Forest function level:" | cut -d ":" -f2 | xargs)
	DOMAINLEVEL=$(samba-tool domain level show | grep "Domain function level:" | cut -d ":" -f2 | xargs)
	LOWESTLEVEL=$(samba-tool domain level show | grep "Lowest function level of a DC:" | cut -d ":" -f2 | xargs)
	DBCHECKRESULT=$(samba-tool dbcheck | grep "Checked")
	PASSCOMPLEX=$(samba-tool domain passwordsettings show | grep "Password complexity:" | cut -d ":" -f2 | xargs)
	PASSHISTORY=$(samba-tool domain passwordsettings show | grep "Password history length:" | cut -d ":" -f2 | xargs)
	MINPASSLENGTH=$(samba-tool domain passwordsettings show | grep "Minimum password length:" | cut -d ":" -f2 | xargs)
	MINPASSAGE=$(samba-tool domain passwordsettings show | grep "Minimum password age (days):" | cut -d ":" -f2 | xargs)
	MAXPASSAGE=$(samba-tool domain passwordsettings show | grep "Maximum password age (days):" | cut -d ":" -f2 | xargs)
	# FSMO ROLES
	SCHEMAMASTER=$(samba-tool fsmo show |grep "SchemaMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	INFRAMASTER=$(samba-tool fsmo show |grep "InfrastructureMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	RIDMASTER=$(samba-tool fsmo show |grep "RidAllocationMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	PDCMASTER=$(samba-tool fsmo show |grep "PdcEmulationMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	NAMINGMASTER=$(samba-tool fsmo show |grep "DomainNamingMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	DDNSMASTER=$(samba-tool fsmo show |grep "DomainDnsZonesMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	FDNSMASTER=$(samba-tool fsmo show |grep "ForestDnsZonesMasterRole" |cut -d "," -f2 | cut -d "=" -f2)
	# DC
	DCLIST=$(samba-tool ou listobjects OU="Domain Controllers" | cut -d "," -f1 | cut -d "=" -f2)
	# DB & SCHEMA
	SCHEMAINFO=$(samba-tool ldapcmp ldap://localhost ldap://localhost --filter=objectclass=schema | grep "Result for" | awk {'print $4,$5'})
	DBSIZE=$(du -skh /var/lib/samba/private/sam.ldb.d/)
	# Listening and Open Ports
	nmap 127.0.0.1 > /tmp/portlist.txt
	PORTS=$(grep -A 100 'PORT' /tmp/portlist.txt | grep -v "Nmap done")
	rm /tmp/portlist.txt
	
	whiptail --msgbox \
		".:: Samba Active Directory Domain Controller Server Report ::. \
		\n---------------------------------------------------------------- \
		\nHostName                 : $SERVERNAME \
		\nServer IP Addr.          : $SERVERIP \
		\nDomain Name              : $DOMAINNAME - Kerberos Name: $KERBEROSNAME \
		\nServer Role              : $SERVERROLE \
		\nForest Level             : $FORESTLEVEL \
		\nDomain Level             : $DOMAINLEVEL \
		\nLowest Level             : $LOWESTLEVEL \
		\n---------------------------------------------------------------- \
		\nPassword Complexity      : $PASSCOMPLEX \
		\nPassword History         : $PASSHISTORY \
		\nMinimum Password Length  : $MINPASSLENGTH \
		\nMinimum Password Age     : $MINPASSAGE \
		\nMaximum Password Age     : $MAXPASSAGE \
		\n---------------------------------------------------------------- \
		\nRegistered DC List \
		\n---------------------------------------------------------------- \
		\n$DCLIST \
		\n---------------------------------------------------------------- \
		\nSchema Master DC         : $SCHEMAMASTER \
		\nInfrastructure Master DC : $INFRAMASTER \
		\nRID Master DC            : $RIDMASTER \
		\nPDC Master DC            : $PDCMASTER \
		\nDomain Naming Master DC  : $NAMINGMASTER \
		\nDomain DNS Master DC     : $DDNSMASTER \
		\nForest DNS Master DC     : $FDNSMASTER \
		\n---------------------------------------------------------------- \
		\nAD, Domain, Configuration and Schema Test Results \
		\n---------------------------------------------------------------- \
		\n$SCHEMAINFO \
		\n---------------------------------------------------------------- \
		\nDB Check Result          : $DBCHECKRESULT \
		\nDomain DB Size           : $DBSIZE \
		\n\n---------------------------------------------------------------- \
		\nhttps://github.com/eesmer/SambaAD-HelperScripts" 0 0 0
		#20 90 45

		# Show PortList
		whiptail --title "Port List" --msgbox "$PORTS" 20 60
		
		exit 1
	}

CHECKRUN_ROOT
CHECK_COMMANDS
UPDATE_CONTROL
REPORTING
#samba-tool domain info $SERVER
#samba-tool processes
#samba-tool ou listobjects OU="Domain Controllers"
