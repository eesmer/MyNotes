#!/bin/bash
set -euo pipefail
set -o errtrace
trap 'ec=$?; echo "[!] Error ($ec): ${BASH_SOURCE[0]}:${BASH_LINENO[0]}: $(printf "%q" "$BASH_COMMAND")" >&2' ERR

export DEBIAN_FRONTEND=noninteractive

HOSTNAME="erkdebian"
TIMEZONE="Europe/Istanbul"
MYUSER="erkan"

hostnamectl set-hostname "$HOSTNAME"
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

cat > /etc/apt/sources.list <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware
EOF
chmod 644 /etc/apt/sources.list

mkdir -p /etc/systemd/timesyncd.conf.d
tee /etc/systemd/timesyncd.conf.d/timesync_custom.conf > /dev/null <<'EOF'
[Time]
NTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org
FallbackNTP=time.google.com pool.ntp.org
EOF
systemctl restart systemd-timesyncd

apt-get update
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

apt-get update && apt-get -y full-upgrade && apt-get -y autoremove --purge && apt-get -y autoclean

# PACKAGES INSTALL
grep -qi 'GenuineIntel' /proc/cpuinfo && apt-get -y install intel-microcode || grep -qi 'AuthenticAMD' /proc/cpuinfo && apt-get -y install amd64-microcode || true
apt-get -y install isenkram-cli && isenkram-autoinstall-firmware || true
apt-get -y install xserver-xorg xserver-xorg-input-libinput xauth
apt-get -y install i3 i3status xtrlock suckless-tools
apt-get -y install xterm xinit xfce4-terminal
apt-get -y install vim tmux openssh-server htop
apt-get -y install sudo
apt-get -y install lxpolkit
apt-get -y install x11-xserver-utils whiptail
apt-get -y install thunar thunar-volman tumbler ffmpegthumbnailer gvfs-backends gvfs-fuse udisks2
apt-get -y install zsh fzf zsh-autosuggestions zsh-syntax-highlighting ripgrep
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
usermod -s /bin/zsh $MYUSER

# === erkwelcome ===

cat > /usr/local/bin/erkwelcome.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

title="ErkWelcome Menu"
while true; do
  CHOICE=$(
    whiptail --title "$title" --menu "Make a Choice:" 20 60 10 \
      1 "Satrt i3" \
      2 "System Upgrade" \
      3 "NW Info" \
      4 "Reboot" \
      5 "Poweroff" \
      0 "Return Shell" \
      3>&1 1>&2 2>&3 || echo "0"
  )

  case "${CHOICE}" in
    1)
      if command -v startx >/dev/null 2>&1; then
        clear
        startx
      else
        whiptail --title "$title" --msgbox "startx command not found" 8 40
      fi
      ;;
    2)
      clear
      sudo apt-get update && sudo apt-get -y full-upgrade || true
      whiptail --title "$title" --msgbox "Update finished" 8 60
      ;;
    3)
      TMP=$(mktemp)
      {
        echo "==== ip -br a ===="; ip -br a || true
        echo; echo "==== ip route ===="; ip route || true
        echo; echo "==== resolvectl ===="; resolvectl status 2>&1 || true
      } > "$TMP"
      whiptail --title "$title" --textbox "$TMP" 25 90
      rm -f "$TMP"
      ;;
    4) sudo reboot ;;
    5) sudo poweroff ;;
    0|*) clear; break ;;
  esac
done
EOF

chown erkan:erkan /usr/local/bin/erkwelcome.sh
chmod 644 /usr/local/bin/erkwelcome.sh
chmod +x /usr/local/bin/erkwelcome.sh

cat > /home/$MYUSER/.zlogin <<'EOF'
if [[ -o interactive && -o login && -z "$DISPLAY" && "${XDG_VTNR:-}" = "1" && -z "${SSH_CONNECTION:-}" ]]; then
  /usr/local/bin/erkwelcome.sh
fi
EOF

chown $MYUSER:$MYUSER /home/$MYUSER/.zlogin
chmod 0644 /home/$MYUSER/.zlogin

