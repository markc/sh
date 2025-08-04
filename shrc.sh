#!/usr/bin/env bash
# Created: 20150101 - Updated: 20250804
# Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License)
# Shell resource configuration - aliases and functions
# This file contains useful aliases and bash functions extracted from
# the NetServa management system. Source this in your ~/.bashrc:
# [[ -f ~/.sh/shrc.sh ]] && . ~/.sh/shrc.sh

# Prevent multiple sourcing
[[ -n "${SHRC_LOADED:-}" ]] && return 0
export SHRC_LOADED=1

# Detect OS type
detect_os() {
    local uname_s=$(uname -s | tr 'A-Z' 'a-z')
    local uname_m=$(uname -m)

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "${ID:-}" in
        alpine | debian | ubuntu | cachyos | manjaro | arch | openwrt)
            OSTYP="$ID"
            ;;
        *)
            case "${ID_LIKE:-}" in
            *debian*) OSTYP="debian" ;;
            *arch*) OSTYP="arch" ;;
            *) OSTYP="${ID:-$uname_s}" ;;
            esac
            ;;
        esac
    elif [[ -f /etc/openwrt_release ]]; then
        OSTYP="openwrt"
    elif [[ "$uname_s" == "darwin" ]]; then
        OSTYP="macos"
    else
        OSTYP="$uname_s"
    fi

    case "$uname_m" in
    x86_64 | amd64) ARCH="x86_64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    armv7l | armhf) ARCH="armv7" ;;
    *) ARCH="$uname_m" ;;
    esac

    export OSTYP ARCH
}

# Initialize environment
detect_os

# Set SUDO if not root
unalias sudo 2>/dev/null || true
SUDO=$([[ $(id -u) -gt 0 ]] && echo '/usr/bin/sudo ')
export SUDO

# Note: Custom user configuration is loaded at the end of this file

# ========== ALIASES ==========

# Navigation and file management
alias ..='cd ..'
alias df='df -kTh'
alias la='LC_COLLATE=C ls -lFAh --group-directories-first --color'
alias ll='LC_COLLATE=C ls -lF --group-directories-first --color'
alias ls='LC_COLLATE=C ls -F --group-directories-first --color'

# Editors
alias e='nano -t -x -c'
alias se='sudo nano -t -x -c'

# System tools
alias ff="fastfetch --logo none --colors-block-width 0"
alias p='ps auxxww | grep -v grep | grep'
alias q='find -type f -print0 | xargs -0 grep '
alias wt="curl -s -w '%{time_total}\n' -o /dev/null"

# Notes
alias n='echo -e "-- $(date) --\n" >> ~/.note && e +10000 ~/.note'
alias sn='[ -f ~/.note ] && cat ~/.note'

# Help and configuration
alias ?='bash ~/.help'
alias eh='e ~/.help'
alias es='e ~/.sh/myrc.sh; shrc_reload'
alias m='bash ~/.menu'

# Package management aliases based on OS type
if [[ $OSTYP == openwrt ]]; then
    alias edpkg=$SUDO'nano -t -x -c /etc/opkg/customfeeds.conf'
    alias i=$SUDO'opkg install'
    alias l=$SUDO'logread -f'
    alias lspkg=$SUDO'opkg list-installed | sort | grep'
    alias p='ps | grep -v grep | grep'
    alias r=$SUDO'opkg remove'
    alias s=$SUDO'opkg list | sort | grep '
    alias u=$SUDO'opkg update && '$SUDO'opkg list-upgradable | cut -f 1 -d " " | xargs -r opkg upgrade'
    alias ram=$SUDO"ps w | grep -v \"   0\" | awk '{print \$3\"\t\"\$5\" \"\$6\" \"\$7\" \"\$8\" \"\$9}' | sort -n"
elif [[ $OSTYP == alpine ]]; then
    alias edpkg=$SUDO'nano -t -x -c /etc/apk/repositories'
    alias i=$SUDO'apk add'
    alias l=$SUDO'tail -f /var/log/messages'
    alias lspkg=$SUDO'apk info | sort | grep'
    alias r=$SUDO'apk del'
    alias ram='ps ax -o rss,vsz,comm | grep -v "   0" | sort -n'
    alias s=$SUDO'apk search -v'
    alias u=$SUDO'apk update && '$SUDO'apk upgrade'
elif [[ $OSTYP == manjaro || $OSTYP == cachyos || $OSTYP == arch ]]; then
    alias edpkg=$SUDO'nano -t -x -c /etc/pacman.conf'
    alias i=$SUDO'pacman -S'
    alias lspkg=$SUDO'pacman -Qs'
    alias r=$SUDO'pacman -Rns'
    alias s=$SUDO'pacman -Ss'
    alias u=$SUDO'pacman -Syu --noconfirm ; '$SUDO' pacman -Scc --noconfirm'
    alias uu='yay -Syyuu --noconfirm ; yay -Scc --noconfirm ; '$SUDO' pacman -Scc --noconfirm'
    alias ram='ps -eo rss:10,vsz:10,%cpu:5,cmd --sort=rss | grep -v "^\s\+0" | cut -c -79'
else
    alias aptkey=$SUDO'apt-key adv --recv-keys --keyserver keyserver.ubuntu.com'
    alias edpkg=$SUDO'nano -t -x -c /etc/apt/sources.list'
    alias i=$SUDO'apt-get install'
    alias lspkg='dpkg --get-selections | awk "{print \$1}" | sort | grep'
    alias r=$SUDO'apt-get remove --purge'
    alias s='apt-cache search'
    alias u=$SUDO'apt-get update && '$SUDO'apt-get -y -f dist-upgrade && '$SUDO'apt-get -y autoremove && '$SUDO'apt-get clean'
    alias ram='ps -eo rss:10,vsz:10,%cpu:5,cmd --sort=rss | grep -v "^\s\+0" | cut -c -79'
fi

# Log viewing aliases
alias l='journalctl -f'
alias dlog='journalctl -f -t pdns_server -t pdns_recursor'
alias hlog='journalctl -f -t hlog'
alias slog='journalctl -f -t sshd'
alias mlog='tail -f /var/log/mail.log'
alias mgrep='mlog | grep '
alias alog='tail -f ../log/access.log'
alias elog='tail -f /var/log/nginx/error.log'
alias plog='tail -f ../log/php-errors.log'

# Firewall/security aliases
alias shblock="nft list set ip sshguard attackers | tr '\n' ' '| sed 's/.*elements = {\([^}]*\)}.*/\1\n/' | sed -r 's/\s+//g' | tr ',' '\n'"
alias oldblock='iptables -A INPUT -j DROP -s '
alias oldshblock='iptables -L -n | grep ^DROP | awk '\''{print $4}'\'' | sort -n'
alias oldunblock='iptables -D INPUT -j DROP -s '

# Mail log processing
alias maillog="journalctl -f -n 10000 | stdbuf -oL grep 'warning: header Subject:' | sed -e 's/mail .*warning: header Subject:\(.*\)/\1/' -e 's/ from .*];//' -e 's/proto=.*$//'"

# Additional tools
alias a='php artisan'
alias c='composer'
alias lx='lxc list'
alias hcp='shm pull; su - sysadm -c "cd var/www/html/hcp; git pull"'

# ========== FUNCTIONS ==========

# Find files by name pattern
f() { 
    if [[ ${OSTYP:-} == openwrt ]]; then
        find . -type f -iname '*'$*'*'
    else
        find . -type f -iname '*'$*'*' -ls
    fi
}

# Service control wrapper
if [[ ${OSTYP:-} == openwrt ]]; then
    sc() { $SUDO /etc/init.d/$2 $1; }
    function getent {
        if [[ $1 == passwd ]]; then
            cat /etc/passwd
        elif [[ $1 == group ]]; then
            cat /etc/group
        fi
    }
    export -f getent
elif [[ ${OSTYP:-} == alpine ]]; then
    sc() {
        # Convert systemd-style service@instance to OpenRC service.instance
        if [[ "$2" == *"@"* ]]; then
            local service_name="${2/@/.}"
        else
            local service_name="$2"
        fi

        # Helper function for WireGuard cleanup
        wg_cleanup() {
            local wg_interface="${service_name#wg-quick.}"
            wg-quick down "$wg_interface" 2>/dev/null || true
        }

        # Handle common actions
        case "$1" in
        enable)
            $SUDO rc-update add "$service_name"
            ;;
        disable)
            $SUDO rc-update del "$service_name"
            ;;
        status)
            $SUDO rc-service "$service_name" status
            ;;
        restart)
            if [[ "$service_name" == wg-quick.* ]]; then
                wg_cleanup
                $SUDO rc-service "$service_name" stop 2>/dev/null || true
            else
                $SUDO rc-service "$service_name" stop
            fi
            $SUDO rc-service "$service_name" start
            ;;
        start)
            [[ "$service_name" == wg-quick.* ]] && wg_cleanup
            $SUDO rc-service "$service_name" start
            ;;
        stop)
            $SUDO rc-service "$service_name" stop
            [[ "$service_name" == wg-quick.* ]] && wg_cleanup
            ;;
        *)
            $SUDO rc-status --all | awk '/\[.*\]/ {print $1}'
            ;;
        esac
    }
else
    sc() {
        if [[ -z $1 ]]; then
            $SUDO systemctl list-units --type=service | awk 'NR>1 {sub(".service", "", $1); print $1}' | head -n -7
        else
            $SUDO systemctl $1 $2
        fi
    }
fi

# Check if file is older than specified seconds
chktime() {
    [[ $(($(stat -c %X $1) + $2)) < $(date +%s) ]] && return 0 || return 1
}

# Get users with UID between 1000-9999
getusers() {
    getent passwd | awk -F: '{if ($3 > 999 && $3 < 9999) print}'
}

# Display user info
getuser() {
    echo "\
UUSER=$UUSER
U_UID=$U_UID
U_GID=$U_GID
VHOST=$VHOST
UPATH=$UPATH
U_SHL=$U_SHL"
}

# Navigate to user directories
go2() {
    if [[ $1 =~ "@" ]]; then
        cd /home/u/${1#*@}*/home/*${1%@*}
    else
        cd /home/u/$1*/var/www
    fi
}

# Search for user in system
grepuser() {
    getusers | grep -E "$1[,:]"
}

# Show database command
getdb() {
    echo $SQCMD
}

# SSH with interactive shell
sx() {
    [[ -z $2 || $1 =~ -h ]] &&
        echo "Usage: sx host command (host must be in ~/.ssh/config)" && return 1
    local _HOST=$1
    shift
    ssh $_HOST -q -t "bash -ci '$@'"
}

# Reload function for es alias
shrc_reload() {
    # Re-detect OS
    detect_os
    
    # Re-source this file which will reload personal config
    source ~/.sh/shrc.sh
    
    echo "Shell environment reloaded"
}

# Export commonly used functions
export -f chktime f getdb getuser getusers go2 grepuser sc sx
export -f detect_os shrc_reload

# Set a simple colored prompt if PS1 not already customized
if [[ "$PS1" == *"@"* ]]; then
    PS1="\[\033[1;31m\]\h \w\[\033[0m\] "
    export PS1
fi

# Load custom user configuration - this should always be last
# so user settings can override defaults
[[ -f ~/.sh/myrc.sh ]] && . ~/.sh/myrc.sh