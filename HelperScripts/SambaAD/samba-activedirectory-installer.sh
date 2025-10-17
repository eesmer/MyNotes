#!/bin/bash

#-------------------------------------------------------------------
# Samba Active Directory Installer
# - It installs the Samba package and its requirements
# - It installs and configures bind9 for DNS
# - It installs and configures the chrony service for the NTP service
# Then, it performs the Domain Name Provisioning process according to the information it receives and configures the smb.conf file.
# The machine on which it is run takes the PDC role and starts working as a DC for the established domain.
# ------------------------------------------------------------------
# This script has been tested in Debian environment.
# It is compatible with Debian
# It should be run in a Debian 11, 12 and 13 (trixie) environment.
# ------------------------------------------------------------------
# USAGE:
# wget https://raw.githubusercontent.com/eesmer/MyNotes/refs/heads/main/HelperScripts/SambaAD/samba-activedirectory-installer.sh
# bash samba-activedirectory-installer.sh
#-------------------------------------------------------------------

#--------------------
# Color Codes
#--------------------
MAGENTA=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
WHITE=$(tput setaf 7)
GRAY=$(tput setaf 8)
RED=$(tput setaf 9)
BLUE=$(tput setaf 12)
NOCOL=$(tput sgr0)
BOLD=$(tput bold)

MIN_DEBIAN_VER=11
LOGFILE="/var/log/samba-ad-install.log"

#---------------------
# InfoBox
#---------------------
whiptail --msgbox \
        ".:: Samba Active Directory Domain Controller Installer (for Debian 13) ::. \
        \n---------------------------------------------------------------- \
        \nThis program is distributed for the purpose of being useful. \
        \nThis program installs Samba Active Directory. \
        \nIt will ask you questions about the domain and it will install and will install it according to the information it receives. \
        \n\nWhen the installation is completed;\na Domain is created and this machine is configured as a Domain Controller. \
        \n---------------------------------------------------------------- \
        \n\nhttps://github.com/eesmer/SambaAD-HelperScripts \
        \nhttps://github.com/eesmer/sambadtui \
        \nhttps://github.com/eesmer/DebianDC \
        \nLogs:$LOGFILE" 20 90 45

#--------------------
# Controls
#--------------------
CHECKRUN_ROOT() {
if ! [[ $EUID -eq 0 ]]; then
        echo -e "${RED}${BOLD}This script should only be run as root user.${NOCOL}" | tee -a $LOGFILE
        exit 1
fi
}

UPDATE_CONTROL() {
    echo -e "${GREEN}Internet and repo access is controlled...${NOCOL}" | tee -a $LOGFILE
    apt update > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}An error occurred while updating APT. Please check your internet or repository access.${NOCOL}" | tee -a $LOGFILE
        exit 1
    fi
    echo -e "${GREEN}Access control successfull${NOCOL}" | tee -a $LOGFILE
}

CHECK_DISTRO() {
    DIST=$(grep -E '^ID=' /etc/*-release 2>/dev/null | cut -d= -f2 | tr -d '"' | head -n 1)
    if [[ "$DIST" != "debian" ]]; then
        echo -e "${RED}${BOLD}This script has only been tested in a Debian environment. It is Debian compatible.${NOCOL}" | tee -a $LOGFILE
        exit 1
    fi

    VER=$(cat /etc/debian_version | cut -d "." -f1)
    if [[ $VER -lt $MIN_DEBIAN_VER ]]; then
        echo -e "${YELLOW}-------------------------------------------------------------------------------------${NOCOL}" | tee -a $LOGFILE
        echo -e "${RED}This script is compatible with at least Debian $MIN_DEBIAN_VER (Bullseye) Current Ver: Debian $VER${NOCOL}" | tee -a $LOGFILE
        echo -e "${YELLOW}-------------------------------------------------------------------------------------${NOCOL}" | tee -a $LOGFILE
        exit 1
    fi
    echo -e "${GREEN}Debian $VER version detected as compatible. (Min. version: $MIN_DEBIAN_VER)${NOCOL}" | tee -a $LOGFILE
}

#-------------------------------------------------------------------
# Install and Configuration
#-------------------------------------------------------------------
SAMBAAD_INSTALL() {
    HNAME=$(whiptail --inputbox "DC Hostname (örn: DC01)" 10 50 --title "DC Hostname" --backtitle "Samba AD Installer" 3>&1 1>&2 2>&3)
    ANSWER=$?
    if [ $ANSWER -ne 0 ]; then echo "User canceled." | tee -a $LOGFILE; exit 1; fi

    REALM=$(whiptail --inputbox "Domain Name (örn: EXAMPLE.LOC)" 10 50 --title "Domain Name" --backtitle "Samba AD Installer" 3>&1 1>&2 2>&3 | tr '[:lower:]' '[:upper:]')
    ANSWER=$?
    if [ $ANSWER -ne 0 ]; then echo "User canceled." | tee -a $LOGFILE; exit 1; fi

    PASSWORD=$(whiptail --passwordbox "Administrator Password" 10 50 --title "Administrator Password" --backtitle "Samba AD Installer" 3>&1 1>&2 2>&3)
    ANSWER=$?
    if [ $ANSWER -ne 0 ]; then echo "User canceled." | tee -a $LOGFILE; exit 1; fi

    if [ -z "$HNAME" ] || [ -z "$REALM" ] || [ -z "$PASSWORD" ]; then
        whiptail --msgbox "Please fill in all fields." --title "Hata" 0 0 0
        SAMBAAD_INSTALL
        return
    fi

    whiptail --yesno "Domain: $REALM\nHostname: $HNAME\n\nDo you want to start the installation?" 0 0 0
    ANSWER=$?
    if [ $ANSWER -ne 0 ]; then echo "User canceled" | tee -a $LOGFILE; exit 1; fi

    DOMAIN=$(echo $REALM | cut -d "." -f1)
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo -e "${YELLOW}Installation is starting... Installation Info: HNAME=$HNAME, REALM=$REALM, DOMAIN=$DOMAIN, IP=$SERVER_IP${NOCOL}" | tee -a $LOGFILE

    echo -e "${GREEN}Hostname and /etc/hosts updating...${NOCOL}" | tee -a $LOGFILE
    hostnamectl set-hostname $HNAME.$REALM
    sed -i "/127.0.1.1/ c $SERVER_IP $HNAME.$REALM $HNAME $REALM" /etc/hosts
    # sed -i "/127.0.1.1/ c 127.0.1.1 $HNAME.$REALM $HNAME $REALM" /etc/hosts

    echo -e "${GREEN}Necessary packages are installing... (Log: $LOGFILE)${NOCOL}" | tee -a $LOGFILE
    export DEBIAN_FRONTEND=noninteractive

    apt-get -y update >> $LOGFILE 2>&1
    apt-get -y upgrade >> $LOGFILE 2>&1
    apt-get -y autoremove >> $LOGFILE 2>&1

    apt-get -y install bind9 bind9utils dnsutils >> $LOGFILE 2>&1
    apt-get -y install samba samba-common-bin >> $LOGFILE 2>&1
    apt-get -y install krb5-user krb5-config >> $LOGFILE 2>&1
    apt-get -y install chrony >> $LOGFILE 2>&1
    apt-get -y install dnsutils net-tools openssh-server >> $LOGFILE 2>&1

    systemctl stop smbd nmbd winbind > /dev/null 2>&1
    systemctl disable smbd nmbd winbind > /dev/null 2>&1
    systemctl mask smbd nmbd winbind > /dev/null 2>&1

    echo -e "${GREEN}Samba Domain Controller is Preparing...${NOCOL}" | tee -a $LOGFILE
    rm -f /etc/samba/smb.conf
    samba-tool domain provision --server-role=dc --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASSWORD" --dns-backend=BIND9_DLZ >> $LOGFILE 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}${BOLD}ERROR: Samba Provisioning failed. Check the log file: $LOGFILE${NOCOL}" | tee -a $LOGFILE
        exit 1
    fi

    echo -e "${GREEN}smb.conf updating...${NOCOL}" | tee -a $LOGFILE
    sed -i 's/dns forwarder = .*/server services = -dns/' /etc/samba/smb.conf

    sed -i "/server services =/a log level = 2" /etc/samba/smb.conf
    sed -i "/log level =/a log file = /var/log/samba/$REALM.log" /etc/samba/smb.conf
    sed -i "/log file =/a debug timestamp = yes" /etc/samba/smb.conf

    echo -e "${GREEN}Kerberos and DNS settings...${NOCOL}" | tee -a $LOGFILE
    rm -f /etc/krb5.conf
    cp /var/lib/samba/private/krb5.conf /etc/

    echo "search $REALM" > /etc/resolv.conf
    echo "nameserver 127.0.0.1" >> /etc/resolv.conf

    echo -e "${GREEN}Time sync settings...${NOCOL}" | tee -a $LOGFILE
    systemctl stop chrony > /dev/null 2>&1

    CHRONY_CONF="/etc/chrony/chrony.conf"
    sed -i '/^pool /d' $CHRONY_CONF # all pool line deleted
    echo "pool 0.debian.pool.ntp.org iburst" >> $CHRONY_CONF # Debian default pool
    echo "allow 0.0.0.0/0" >> $CHRONY_CONF
    echo "ntpsigndsocket  /var/lib/samba/ntp_signd" >> $CHRONY_CONF

    chown root:_chrony /var/lib/samba/ntp_signd/
    chmod 750 /var/lib/samba/ntp_signd/

    systemctl enable chrony > /dev/null 2>&1
    systemctl restart chrony

    echo -e "${GREEN}BIND9 DLZ Configuration...${NOCOL}" | tee -a $LOGFILE

    # dlz_bind9_.so find path
    DLZ_PATH=$(dpkg -L samba-common-bin | grep dlz_bind9 | head -n 1)

    if [ -z "$DLZ_PATH" ]; then
        echo -e "${YELLOW}Warning: The dlz_bind9 module path was not found. The default path is being used.${NOCOL}" | tee -a $LOGFILE
        # Debian 12/13 default path x86_64
        DLZ_PATH="/usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_10.so"
    fi

# named.conf.options
    cat > /etc/bind/named.conf.options << EOF
options {
        directory "/var/cache/bind";
        forwarders { 8.8.8.8; 8.8.4.4; };
        allow-query { any; };
        dnssec-validation no;
        auth-nxdomain no;    # RFC1035
        listen-on-v6 { any; };
        tkey-gssapi-keytab "/var/lib/samba/bind-dns/dns.keytab";
        minimal-responses yes;
};
EOF

# named.conf.local
    cat > /etc/bind/named.conf.local << EOF
dlz "$REALM" {
        database "dlopen $DLZ_PATH";
};
EOF

# named default settings (for IPv4 listening)
    cat > /etc/default/named << EOF
RESOLVCONF=no
OPTIONS="-4 -u bind"
EOF

chmod 644 /etc/default/named

SAMBAAD_INSTALL() {
	HNAME=$(whiptail --inputbox "Enter DC Machine Hostname (e.g.,DC01)" 10 50 --title "DC Hostname" --backtitle "DC Hostname" 3>&1 1>&2 2>&3)
        ANSWER=$?
        if [ ! $ANSWER = 0 ]; then
                echo "User canceled"
		exit 1
        fi
	REALM=$(whiptail --inputbox "Enter Domain Name (e.g., EXAMPLE.LOC)" 10 50 --title "DomainName" --backtitle "Domain Name" 3>&1 1>&2 2>&3)
	ANSWER=$?
	if [ ! $ANSWER = 0 ]; then
		echo "User canceled"
		exit 1
	fi
        PASSWORD=$(whiptail --passwordbox "Enter Administrator Password" 10 50 --title "Administrator Password" --backtitle "Administrator Password" 3>&1 1>&2 2>&3)
	ANSWER=$?
	if [ ! $ANSWER = 0 ]; then
		echo "User canceled"
		exit 1
	fi
	if [ -z "$HNAME" ] || [ -z "$REALM" ] || [ -z "$PASSWORD" ]; then
		whiptail --msgbox "Please fill in all fields.." --title "SambaAD Install" --backtitle "Samba Active Directory Installation" 0 0 0
		SAMBAAD_INSTALL
	fi

	whiptail --yesno "Domain Name: $REALM\n Start Installation?" 0 0 0
	ANSWER=$?
	if [ ! $ANSWER = 0 ]; then
		echo "User canceled"
		exit 1
	fi

	SERVER_IP=$(ip r | grep link | grep src | cut -d '/' -f2 | cut -d'c' -f3 | cut -d ' ' -f2)
	DOMAIN=$(echo $REALM | cut -d "." -f1)
	#sed -i "/127.0.1.1/ c 127.0.1.1 $HOSTNAME.$REALM $HOSTNAME" /etc/hosts
	sed -i "/127.0.1.1/ c 127.0.1.1 $HNAME.$REALM $HNAME $REALM" /etc/hosts
	hostnamectl set-hostname $HNAME.$REALM
	
	export DEBIAN_FRONTEND=noninteractive
	apt-get -y update && apt-get -y upgrade && apt-get -y autoremove
	apt-get -y install bind9 bind9utils dnsutils
	apt-get -y install samba --install-recommends
	apt-get -y install winbind
	apt-get -y install krb5-config krb5-user
	
	systemctl stop smbd nmbd winbind
	systemctl disable smbd nmbd winbind
	systemctl mask smbd nmbd winbind

	apt-get -y install chrony ntpdate
	apt-get -y install dnsutils net-tools
	apt-get -y install openssh-server 
	#apt-get -y install ack expect krb5-user krb5-config
	#apt-get -y install curl wget
	
	#Domain Provision
	rm /etc/samba/smb.conf
	samba-tool domain provision --server-role=dc --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASSWORD"
	
	##Log Config
	#sed -i '/server services =/a log level = 4' /etc/samba/smb.conf
	#sed -i '/log level =/a log file = /var/log/samba/$REALM.log' /etc/samba/smb.conf
	#sed -i '/log file =/a debug timestamp = yes' /etc/samba/smb.conf
	
	#Time/Sync Config
	ntpdate -bu pool.ntp.org
	echo "allow 0.0.0.0/0" >> /etc/chrony/chrony.conf
	echo "ntpsigndsocket  /var/lib/samba/ntp_signd" >> /etc/chrony/chrony.conf
	chown root:_chrony /var/lib/samba/ntp_signd/
	chmod 750 /var/lib/samba/ntp_signd/
	systemctl restart chrony
	systemctl enable chrony
	#sed -i "s/\$IP/$SERVER_IP/" /var/lib/samba/private/dns_update_list
	
	rm /etc/krb5.conf
	cp /var/lib/samba/private/krb5.conf /etc/
	echo "search $REALM" > /etc/resolv.conf
	echo "nameserver 127.0.0.1" >> /etc/resolv.conf

# named.conf.options
cat > /etc/bind/named.conf.options << EOF
options {
directory "/var/cache/bind";

forwarders {
8.8.8.8;
};

allow-query { any; };
dnssec-validation no;

auth-nxdomain no; #RFC1035
listen-on-v6 { any; };

tkey-gssapi-keytab "/var/lib/samba/bind-dns/dns.keytab";
minimal-responses yes;
};
EOF

# named.conf.local
cat > /etc/bind/named.conf.local << EOF
dlz "$REALM" {
database "dlopen /usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_10.so";
};
EOF

cat > /etc/default/named << EOF
RESOLVCONF=no
OPTIONS="-4 -u bind"
EOF
chmod 644 /etc/default/named

sed -i 's/dns forwarder = .*/server services = -dns/' /etc/samba/smb.conf
mkdir -p /var/lib/samba/bind-dns
mkdir -p /var/lib/samba/bind-dns/dns

##Log Config
sed -i "/server services =/a log level = 2" /etc/samba/smb.conf
sed -i "/log level =/a log file = /var/log/samba/$REALM.log" /etc/samba/smb.conf
sed -i "/log file =/a debug timestamp = yes" /etc/samba/smb.conf

samba_upgradedns --dns-backend=BIND9_DLZ

systemctl unmask samba-ad-dc.service
systemctl enable samba-ad-dc.service
systemctl restart samba-ad-dc
systemctl restart bind9
}

CHECKRUN_ROOT
CHECK_DISTRO
UPDATE_CONTROL
SAMBAAD_INSTALL
