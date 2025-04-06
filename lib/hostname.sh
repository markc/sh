# Created: 20250406
# Copyright (C) 1995-2025 Mark Constable <markc@renta.net> (AGPL-3.0)

# Function to get the Fully Qualified Domain Name
get_fqdn() {
    local hostname=$(uname -n)
    local domain=""
    local fqdn=""

    # Check if /etc/systemd/resolved.conf exists
    if [ -f /etc/systemd/resolved.conf ]; then
        # Check if "Domains=" line exists
        if grep -q "^Domains=" /etc/systemd/resolved.conf; then
            # Extract the domain using awk
            domain=$(grep "^Domains=" /etc/systemd/resolved.conf | awk -F= '{print $2}')
        fi
    fi

    # Construct the FQDN
    if [ -n "$domain" ]; then
        fqdn="${hostname}.${domain}"
    else
        fqdn="$hostname"  # Default to just the hostname if no domain is set
    fi

    # Convert to lowercase (as you did with tr 'A-Z' 'a-z')
    fqdn=$(echo "$fqdn" | tr 'A-Z' 'a-z')

    echo "$fqdn"
}

# Function to simulate getent calls on OpenWrt
function getent
{
    if [[ $1 == passwd ]]; then
        cat /etc/passwd
    elif [[ $1 == group ]]; then
        cat /etc/group
    fi
}

# Overwrite the hostname command to have a consistent response!
hostname () {

    [[ $DEBUG ]] && echo "inside hostname()" >&2

    # Use standard function if Proxmox machine (Detect if running on Proxmox hypervisor by looking for /etc/pve)

    if [ -d /etc/pve ]; then
       /usr/bin/hostname "$@"
    elif [[ -f /etc/os-release ]] && [[ $(awk -F= '/^ID=/ {print $2}' /etc/os-release | sed 's/"//g') == openwrt ]]; then

        # OpenWrt implementation uses uci to get to host and domain values.

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
    else
        # SystemD implementation using systemd-resolved.
        if [[ -z $1 ]]; then
            uname -n
        elif [[ $1 == "-f" ]]; then
            get_fqdn
        else
            /usr/bin/hostname "$@" # Pass other arguments to the system hostname command
        fi
    fi
}
