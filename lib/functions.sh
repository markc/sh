# Created: 20151231 - Updated: 20250716
# Copyright (C) 1995-2025 Mark Constable <markc@renta.net> (AGPL-3.0)

f() { find . -type f -iname '*'$*'*'; }

if [[ $OSTYP == openwrt ]]; then
    sc() { $SUDO /etc/init.d/$2 $1; }
    function getent {
        if [[ $1 == passwd ]]; then
            cat /etc/passwd
        elif [[ $1 == group ]]; then
            cat /etc/group
        fi
        export -f getent
    }
elif [[ $OSTYP == alpine ]]; then
    sc() {
        # Convert systemd-style service@instance to OpenRC service.instance
        if [[ "$2" == *"@"* ]]; then
            local service_name="${2/@/.}"
        else
            local service_name="$2"
        fi

        if [[ $1 == restart ]]; then
            $SUDO rc-service "$service_name" stop
            $SUDO rc-service "$service_name" start
        else
            if [[ $1 == start || $1 == stop || $1 == status ]]; then
                $SUDO rc-service "$service_name" "$1"
            else
                if [[ $1 == enable ]]; then
                    $SUDO rc-update add "$service_name"
                else
                    if [[ $1 == disable ]]; then
                        $SUDO rc-update del "$service_name"
                    else
                        $SUDO rc-status --all | awk '/\[.*\]/ {print $1}'
                    fi
                fi
            fi
        fi
    }
else
    f() { find . -type f -iname '*'$*'*' -ls; }
    sc() {
        if [[ -z $1 ]]; then
            $SUDO systemctl list-units --type=service | awk 'NR>1 {sub(".service", "", $1); print $1}' | head -n -7
        else
            $SUDO systemctl $1 $2
        fi
    }
fi

chktime() {
    [[ $(($(stat -c %X $1) + $2)) < $(date +%s) ]] && return 0 || return 1
}

gethost() {
    cat <<EOS
ADMIN='$ADMIN'
AHOST='$AHOST'
AMAIL='$AMAIL'
ANAME='$ANAME'
APASS='$APASS'
A_GID='$A_GID'
A_UID='$A_UID'
BPATH='$BPATH'
CIMAP='$CIMAP'
CSMTP='$CSMTP'
C_DNS='$C_DNS'
C_FPM='$C_FPM'
C_SQL='$C_SQL'
C_SSL='$C_SSL'
C_WEB='$C_WEB'
DBMYS='$DBMYS'
DBSQL='$DBSQL'
DHOST='$DHOST'
DNAME='$DNAME'
DPASS='$DPASS'
DPATH='$DPATH'
DPORT='$DPORT'
DTYPE='$DTYPE'
DUSER='$DUSER'
EPASS='$EPASS'
EXMYS='$EXMYS'
EXSQL='$EXSQL'
HDOMN='$HDOMN'
HNAME='$HNAME'
IP4_0='$IP4_0'
MHOST='$MHOST'
MPATH='$MPATH'
OSMIR='$OSMIR'
OSREL='$OSREL'
OSTYP='$OSTYP'
SQCMD='$SQCMD'
SQDNS='$SQDNS'
TAREA='$TAREA'
TCITY='$TCITY'
UPASS='$UPASS'
UPATH='$UPATH'
UUSER='$UUSER'
U_GID='$U_GID'
U_SHL='$U_SHL'
U_UID='$U_UID'
VHOST='$VHOST'
VPATH='$VPATH'
VUSER='$VUSER'
V_PHP='$V_PHP'
WPASS='$WPASS'
WPATH='$WPATH'
WPUSR='$WPUSR'
WUGID='$WUGID'
EOS
}

getusers() {
    getent passwd | awk -F: '{if ($3 > 999 && $3 < 9999) print}'
}

getuser() {
    echo "\
UUSER=$UUSER
U_UID=$U_UID
U_GID=$U_GID
VHOST=$VHOST
UPATH=$UPATH
U_SHL=$U_SHL"
}

go2() {
    if [[ $1 =~ "@" ]]; then
        cd /home/u/${1#*@}*/home/*${1%@*}
    else
        cd /home/u/$1*/var/www
    fi
}

grepuser() {
    getusers | grep -E "$1[,:]"
}

newuid() {
    local uid=$(($(getusers | cut -d: -f3 | sort -n | tail -n1) + 1))
    [[ $uid == 1 ]] && echo 1000 || echo $uid
}

getdb() {
    echo $SQCMD
}

setuser() {
    local U_TMP=$(grepuser "$1")
    [[ $U_TMP && (($(grep -c . <<<"$U_TMP") != 1)) ]] && echo "Ambiguous result for '$1'" && return 10
    UUSER=$(echo $U_TMP | cut -d: -f1)
    U_UID=$(echo $UUSER | cut -d: -f3)
    U_GID=$(echo $UUSER | cut -d: -f4)
    VHOST=$(echo $UUSER | cut -d: -f5)
    UPATH=$(echo $UUSER | cut -d: -f6)
    U_SHL=$(echo $UUSER | cut -d: -f7)
}

sethost() {
    [[ $1 =~ -h ]] && echo "Usage: sethost [domain]" && return 1

    local _FQDN=$(hostname -f | tr 'A-Z' 'a-z')

    [[ $DEBUG ]] && echo "local _FQDN=$_FQDN" >&2

    # Static env var defaults, can also be set in ~/.myrc via "es"

    ADMIN=${ADMIN:-'sysadm'}
    A_GID=${A_GID:-'1000'}
    A_UID=${A_UID:-'1000'}
    ANAME=${ANAME:-'System Administrator'}
    BPATH=${BPATH:-'/home/backups'}
    CIMAP=${CIMAP:-'/etc/dovecot'}
    CSMTP=${CSMTP:-'/etc/postfix'}
    C_DNS=${C_DNS:-'/etc/powerdns'}
    C_SQL=${C_SQL:-'/etc/mysql'}
    C_SSL=${C_SSL:-'/etc/ssl'}
    C_WEB=${C_WEB:-'/etc/nginx'}
    DBMYS=${DBMYS:-'/var/lib/mysql'}
    DBSQL=${DBSQL:-'/var/lib/sqlite'}
    DHOST=${DHOST:-'localhost'}
    DPORT=${DPORT:-'3306'}
    DTYPE=${DTYPE:-'mysql'}
    OSMIR=${OSMIR:-'archive.ubuntu.com'}
    OSREL=${OSREL:-'noble'}
    OSTYP=${OSTYP:-'ubuntu'}
    TAREA=${TAREA:-'Australia'}
    TCITY=${TCITY:-'Sydney'}
    V_PHP=${V_PHP:-'8.3'}
    VPATH=${VPATH:-'/home/u'}
    VUSER=${VUSER:-'admin'}
    WUGID=${WUGID:-'www-data'}

    # Dynamic env vars dependant on other env vars

    VHOST=${1:-${VHOST:-"$_FQDN"}}
    U_UID=$([[ $_FQDN == $VHOST ]] && echo "$A_UID" || newuid)
    UUSER=$([[ $U_UID == $A_UID ]] && echo "$ADMIN" || echo "u$U_UID")

    AHOST=${AHOST:-"$_FQDN"}
    APASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)
    C_FPM="/etc/php/$V_PHP/fpm"
    DPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)
    DPATH="$DBSQL/$ADMIN/$ADMIN.db"
    DUSER="$UUSER"
    EPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)
    EXMYS="mariadb -BN $ADMIN"
    EXSQL="sqlite3 $DPATH"
    HDOMN=${VHOST#*.}
    HNAME=${VHOST%%.*}
    IP4_0=$(ip -4 route get 1.1.1.1 | awk '/src/ {print $7}')
    MHOST=$([[ $HNAME == mail ]] && echo "$HNAME.$HDOMN" || echo "$VHOST")
    SQCMD=$([[ $DTYPE == mysql ]] && echo "$EXMYS" || echo "$EXSQL")
    SQDNS=$([[ $DTYPE == mysql ]] && echo "mariadb -BN pdns" || echo "sqlite3 $DBSQL/$ADMIN/pdns.db")
    UPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)
    UUSER=$([[ $U_UID == $A_UID ]] && echo "$ADMIN" || echo "u$U_UID")
    U_GID="$U_UID"
    U_SHL=$([[ $U_UID == $A_UID ]] && echo "/bin/bash" || echo "/bin/sh")
    WPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)
    WPATH="$VPATH/$VHOST/var/www/html"
    WPUSR=$(head /dev/urandom | tr -dc a-z | head -c6)

    AMAIL="$VUSER@${VHOST#mail.}"
    DNAME=$([[ $UUSER == $ADMIN ]] && echo "$ADMIN" || echo "${VHOST//[.-]/_}")
    UPATH="$VPATH/$VHOST"
    MPATH="$UPATH/home"

    # OS dependent overrides (WIP)

    if [[ $OSTYP == alpine || $OSTYP == linux-musl ]]; then
        V_PHP='84'
        C_DNS='/etc/pdns'
        C_FPM="/etc/php$V_PHP"
        C_SQL='/etc/my.cnf.d'
        EXMYS="mariadb -BN $ADMIN"
        OSMIR='dl-cdn.alpinelinux.org'
        OSREL='latest-stable'
        WUGID='nginx'
    elif [[ $OSTYP == debian ]]; then
        V_PHP='8.2'
        OSMIR='deb.debian.org'
        OSREL='bookworm'
    elif [[ $OSTYP == manjaro || $OSTYP == cachyos ]]; then
        V_PHP='8.4'
        C_DNS='/etc/powerdns'
        C_FPM='/etc/php'
        C_SQL='/etc/my.cnf.d'
        OSMIR='manjaro.moson.eu'
        OSREL='stable'
        if [[ $OSTYP == cachyos ]]; then
            OSMIR='archlinux.cachyos.org'
            OSREL='n/a'
        fi
        WUGID='http'
        #    elif [[ $OSTYP == openwrt ]]; then
        #        echo "TODO: add settings for OpenWrt"
    fi
}

#-T' Disable pseudo-tty allocation.
#-t' Force pseudo-tty allocation. This can be used to execute arbitrary screen-based programs on a remote machine, which can be very useful, e.g. when implementing menu services. Multiple -t options force tty allocation, even if ssh has no local tty.

sx() {
    [[ -z $2 || $1 =~ -h ]] &&
        echo "Usage: sx host command (host must be in ~/.ssh/config)" && return 1
    local _HOST=$1
    shift
    ssh $_HOST -q -t "bash -ci '$@'"
}
