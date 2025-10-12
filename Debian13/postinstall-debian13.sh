#!/bin/bash

#-------------------------------------------------------------------------
# Debian 13 PostInstall
# Debian13-postinstall.sh
# This script customizes my Debian installation for personal use.
# It includes the tools and configurations I use.
# Prepared for Debian 13 / Tested with Debian 13
#-------------------------------------------------------------------------

set -euo pipefail
set -o errtrace
trap 'ec=$?; echo "[!] Error ($ec): ${BASH_SOURCE[0]}:${BASH_LINENO[0]}: $(printf "%q" "$BASH_COMMAND")" >&2' ERR

export DEBIAN_FRONTEND=noninteractive

# --------------------------------------------
# Install Config
# --------------------------------------------
HOSTNAME="erkdebian"
TIMEZONE="Europe/Istanbul"
MYUSER="erkan"
# --------------------------------------------

# === HOSTNAME and TIMEDATE Settings ===
hostnamectl set-hostname "$HOSTNAME"
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

# === MYUSER Settings ===
usermod -aG sudo "$MYUSER"

# === APT REPO / CUSTOM REPO ===
cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
grep -q '^deb .*\(brave-browser-apt-release\|brave.com\)' /etc/apt/sources.list || \
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main' >> /etc/apt/sources.list
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
grep -q '^deb .*/linux/chrome/deb' /etc/apt/sources.list || \
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main' >> /etc/apt/sources.list
chmod 644 /etc/apt/sources.list

apt-get update

# === TIME/SYNC ===
mkdir -p /etc/systemd/timesyncd.conf.d
tee /etc/systemd/timesyncd.conf.d/timesync_custom.conf > /dev/null <<'EOF'
[Time]
NTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org
FallbackNTP=time.google.com pool.ntp.org
EOF
systemctl restart systemd-timesyncd

apt-get install -y locales
sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^# *\(tr_TR.UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_TIME=tr_TR.UTF-8

cat >/etc/apt/preferences.d/99-backports <<'EOF'
Package: *
Pin: release n=trixie-backports
Pin-Priority: 100
EOF

mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99-options <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Retries "3";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

# === PACKAGES ===
grep -qi 'GenuineIntel' /proc/cpuinfo && apt-get -y install intel-microcode || grep -qi 'AuthenticAMD' /proc/cpuinfo && apt-get -y install amd64-microcode || true
apt-get -y install isenkram-cli && isenkram-autoinstall-firmware || true
apt-get -y install xserver-xorg xserver-xorg-input-libinput xauth
apt-get -y install systemd-resolved
apt-get -y install i3 i3status xtrlock suckless-tools
apt-get -y install xterm xinit xfce4-terminal
apt-get -y install vim tmux openssh-server htop
apt-get -y install sudo
apt-get -y install lxpolkit
apt-get -y install x11-xserver-utils whiptail
apt-get -y install thunar thunar-volman tumbler ffmpegthumbnailer gvfs-backends gvfs-fuse udisks2
apt-get -y install zsh fzf zsh-autosuggestions zsh-syntax-highlighting
apt-get -y install feathernotes atril pavucontrol unzip xfce4-terminal freerdp2-x11 vlc feh xdg-utils desktop-file-utils
apt-get -y install ripgrep ack wget curl rsync dnsutils net-tools
apt-get -y install mtr-tiny traceroute nmap htop lsof tcpdump iperf3 ncdu pv jq ca-certificates gpg
apt-get -y install pinentry-curses git git-credential-libsecret git-delta
apt-get -y install firefox-esr chromium
apt-get -y install brave-browser google-chrome-stable
apt-get -y install libreoffice-writer libreoffice-calc libreoffice-impress
# gocryptfs wireguard-tools gnupg 

apt-get update && apt-get -y full-upgrade && apt-get -y autoremove --purge && apt-get -y autoclean

if update-alternatives --list x-terminal-emulator >/dev/null 2>&1; then
  update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper 2>/dev/null || \
  update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal 2>/dev/null || true
fi

# === MIME Defaults for $MYUSER(erkan) ===
mkdir -p "/home/$USER/.config"
chmod 0700 "/home/$USER/.config"
chown $MYUSER:$MYUSER "/home/$USER/.config"
mkdir -p "/home/$MYUSER/.local/share/applications"
chmod 0700 "/home/$MYUSER/.config"
chmod 0700 "/home/$MYUSER/.local" "/home/$MYUSER/.local/share" "/home/$MYUSER/.local/applications"
chown -R "$MYUSER:$MYUSER" "/home/$MYUSER/.config" "/home/$MYUSER/.local"

cat >"/home/$MYUSE/.config/mimeapps.list" <<'EOF'
[Default Applications]
image/jpeg=feh.desktop
image/png=feh.desktop
image/gif=feh.desktop
image/webp=feh.desktop
image/bmp=feh.desktop
image/tiff=feh.desktop
video/mp4=vlc.desktop
video/x-matroska=vlc.desktop
video/x-msvideo=vlc.desktop
video/webm=vlc.desktop
video/x-ms-wmv=vlc.desktop
video/mpeg=vlc.desktop
application/pdf=atril.desktop
inode/directory=Thunar.desktop
EOF
chmod 0644 "/home/$MYUSER/.config/mimeapps.list"

# === DAILY SCRIPTS ===
wget -r -np -nH --cut-dirs=2 -R "index.html*" -N -P ./daily-scripts https://esmerkan.com/fileserver/daily-scripts/

# === MY .zshrc CONFIG ===
cat >"/home/$MYUSER/.zshrc" <<'EOF'
# ==== MY .zshrc ====

# === Directory and Files Color Setting ===
export LS_COLORS="$LS_COLORS:*.sh=0;32:*.py=0;32:*.json=0;32:*.jpg=0;35:*.png=0;35:*.pdf=0;36:*.xls=0;36:*.xlsx=0;36:*.doc=0;36:*.docx=0;36:*.txt=0;90:*.log=0;90:*.zip=0;31:*.tar=0;31:*.gz=0;31"

# === Alias ===
alias off='sudo poweroff'
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias off='sudo poweroff'

# === Color ZSH Completion (Use LS_COLORS Pallet) ===
zmodload zsh/complist
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# === Color man (less) ===
export LESS='-R'
export LESS_TERMCAP_mb=$'\e[1;31m'   # blink -> bold red
export LESS_TERMCAP_md=$'\e[1;36m'   # bold  -> cyan
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;44;37m' # standout (başlık satırı)
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'   # underline -> green
export LESS_TERMCAP_ue=$'\e[0m'

# === History ====
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY

# === Keymap ===
bindkey -e

# === Completion ===
autoload -Uz compinit && compinit
zmodload zsh/complist
zstyle ':completion:*' menu select
setopt AUTO_MENU MENU_COMPLETE

# === fzf settings ===
export FZF_TMUX=1
export FZF_TMUX_OPTS='-d 15'
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*" 2>/dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -f /usr/share/doc/fzf/examples/completion.zsh    ]] && source /usr/share/doc/fzf/examples/completion.zsh
export FZF_CTRL_R_OPTS='--sort --exact'

# === Autosuggest + syntax highlighting ===
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# === Prompt Settings ===
zstyle ':completion:*:*:vim:*' file-sort modification
autoload -Uz colors && colors
PROMPT='%F{cyan}%n@%m%f:%F{yellow}%~%f %# '

EOF

chown "$MYUSER:$MYUSER" "/home/$MYUSER/.zshrc"
chmod 0644 "/home/$MYUSER/.zshrc"
###usermod -s /bin/zsh $MYUSER

# === erkwelcome.sh wrapper ===
cat >/usr/local/bin/erkwelcome-wrapper <<'EOF'
# /usr/local/bin/erkwelcome-wrapper
#!/bin/sh
# Sadece Ctrl+C/Z/\ kilitle; TERM/HUP default kalsın ki kapanışta süreç hemen bitsin
trap '' INT TSTP QUIT # HUB TERM for poweroff

if [ -z "$DISPLAY" ] && [ -z "${SSH_CONNECTION:-}" ] && [ "${XDG_VTNR:-}" = "1" ]; then
  [ -e /run/systemd/shutdown/scheduled ] && exit 0
  exec /usr/local/bin/erkwelcome.sh
fi
exec /bin/zsh -l
EOF

chmod 0755 /usr/local/bin/erkwelcome-wrapper

grep -qxF /usr/local/bin/erkwelcome-wrapper /etc/shells || echo /usr/local/bin/zsh-login-wrapper >> /etc/shells
usermod -s /usr/local/bin/erkwelcome-wrapper erkan

# === erkwelcome ===
cat > /usr/local/bin/erkwelcome.sh <<'EOF'
#!/usr/bin/env bash
set -u -o pipefail

# --- Ctrl+C/Z/\ Signals disabled
trap 'printf "\n[!] Ctrl+C disabled\n" >/dev/tty' INT
trap 'printf "\n[!] Ctrl+Z disabled\n" >/dev/tty' TSTP
trap 'printf "\n[!] Ctrl+\\ disabled\n" >/dev/tty' QUIT

disk_root_percent() { df -P -h / | awk 'NR==2{print $5}'; }

ram_one_liner() {
  local t a
  t=$(free -m | awk '/^Mem:/ {print $2}')
  a=$(free -m | awk '/^Mem:/ {print $7}')
  awk -v t="$t" -v a="$a" 'BEGIN{
    used=t-a; pct=(t>0)?(used*100/t):0;
    printf "%.1f/%.1f GB (%.0f%%)", used/1024, t/1024, pct
  }'
}

short_ip() {
  ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -n1
}

default_gw() {
  ip route 2>/dev/null | awk '/^default/ {print $3; exit}'
}

pause() {
  local msg="${*:-Press Enter to continue}"
  read -rp "$msg" _
}

start_i3() {
  echo "Starting i3..."
  startx
}

check_update() {
  clear
  echo "=== Check Update (simulation) ==="
  sudo apt-get update
  local out sec tot
  out=$(apt-get -s upgrade 2>/dev/null | awk '/^Inst /{print}')
  sec=$(printf "%s\n" "$out" | awk '/\(.*-security\)/{c++} END{print c+0}')
  tot=$(printf "%s\n" "$out" | awk 'END{print NR+0}')
  echo "Total upgradable : ${tot:-0}"
  echo "Security updates : ${sec:-0}"
  echo
  if [ -n "$out" ]; then
    echo "Packages:"
    echo "$out" | sed 's/^/  - /'
  else
    echo "System is up to date."
  fi
  echo
  pause
}

show_menu() {
  #local host now rootp ram ip gw
  HOST=$(hostname)
  NOW=$(date '+%F %T %Z')
  DISK=$(disk_root_percent)
  RAM=$(ram_one_liner)
  IP=$(short_ip); [ -z "$IP" ] && IP="-"
  GW=$(default_gw); [ -z "$GW" ] && GW="-"
  
  echo ""
  echo " |-----------------------------------------------------------------------|"
  echo " | erkWelcome v0.6           :::.. Welcome Screen ..:::                  |"
  echo " |-----------------------------------------------------------------------|"
  echo " | :: Actions ::        | :: Controls/Reports ::                         |"
  echo " |-----------------------------------------------------------------------|"
  echo " | 1.Start i3           | 11.Check Update                                |"
  echo " | 2.Reboot             |                                                |"
  echo " | 3.Poweroff           |                                                |"
  echo " -------------------------------------------------------------------------"
  echo "  $HOST | $NOW  "
  echo "  $DISK | $RAM  "
  echo "  $IP   | $GW   "
  echo " |-----------------------------------------------------------------------|"
}

read_input() {
  local c
  read -rp "You can choose from the menu numbers: " c
  case "$c" in
    1) start_i3 ;;
    2) exec sudo systemctl reboot ;;
    3) exec sudo systemctl poweroff ;;
    11) check_update ;;
    *)  echo "Please select from the menu numbers"; pause ;;
  esac
}

# CTRL+C/Z/\ locked
while true; do
  clear
  show_menu
  read_input
done

EOF

chown $MYUSER:$MYUSER /usr/local/bin/erkwelcome.sh
chmod 755 /usr/local/bin/erkwelcome.sh
chmod +x /usr/local/bin/erkwelcome.sh

cat > /home/$MYUSER/.zlogin <<'EOF'
if [[ -o interactive && -o login && -z "$DISPLAY" && "${XDG_VTNR:-}" = "1" && -z "${SSH_CONNECTION:-}" ]]; then
  /usr/local/bin/erkwelcome.sh
fi
EOF

chown $MYUSER:$MYUSER /home/$MYUSER/.zlogin
chmod 0644 /home/$MYUSER/.zlogin

