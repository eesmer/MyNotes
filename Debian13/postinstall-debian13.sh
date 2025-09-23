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
grep -qi 'GenuineIntel' /proc/cpuinfo && apt-get install -y intel-microcode || grep -qi 'AuthenticAMD' /proc/cpuinfo && apt-get install -y amd64-microcode || true
apt-get install -y isenkram-cli && isenkram-autoinstall-firmware || true
apt-get install -y xserver-xorg xserver-xorg-input-libinput xauth
apt-get -y install i3 i3status suckless-tools
apt-get -y install lxpolkit
apt-get -y install xterm xinit xfce4-terminal
apt-get -y install thunar thunar-volman tumbler ffmpegthumbnailer gvfs-backends gvfs-fuse udisks2
apt-get -y install vim tmux openssh-server htop
apt-get install -y zsh fzf zsh-autosuggestions zsh-syntax-highlighting ripgrep
# === MY .zshrc config ===
cat >"/home/$MYUSER/.zshrc" <<'EOF'
# ==== MY .zshrc ====

# === Directory and Files Color Setting ===
export LS_COLORS="$LS_COLORS:*.sh=0;32:*.py=0;32:*.json=0;32:*.jpg=0;35:*.png=0;35:*.pdf=0;36:*.xls=0;36:*.xlsx=0;36:*.doc=0;36:*.docx=0;36:*.txt=0;90:*.log=0;90:*.zip=0;31:*.tar=0;31:*.gz=0;31"

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
usermod -s /bin/zsh erkan

