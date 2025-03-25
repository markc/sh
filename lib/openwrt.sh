# Created: 20250325 - Updated: 20250325
# Copyright (C) 1995-2025 Mark Constable <markc@renta.net> (AGPL-3.0)

function getent
{
    if [[ $1 == passwd ]]; then
        cat /etc/passwd
    elif [[ $1 == group ]]; then
        cat /etc/group
    fi
}

hostname ()
{
    local _host=$($SUDO uci get system.@system[0].hostname)
    local _wan=$(ip route | grep default | awk '{print $9}')

    if [[ -z $1 ]]; then
        echo "$_host"
    else
        if [[ $1 == -f ]]; then
            echo "$_host.$($SUDO uci get dhcp.@dnsmasq[0].domain)"
        elif [[ $1 == -i ]]; then
            echo "$_wan"
        else
            if [[ $1 == -d ]]; then
                $SUDO uci get dhcp.@dnsmasq[0].domain
            fi
        fi
    fi
}
