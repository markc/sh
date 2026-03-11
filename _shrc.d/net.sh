# Network diagnostics: WHOIS lookups, firewall management
# Source from ~/.myrc on servers: source ~/.rc/_shrc.d/net.sh

# Firewall/security aliases
alias shblock="nft list set ip sshguard attackers | tr '\n' ' '| sed 's/.*elements = {\([^}]*\)}.*/\1\n/' | sed -r 's/\s+//g' | tr ',' '\n'"
alias oldblock='iptables -A INPUT -j DROP -s '
alias oldshblock='iptables -L -n | grep ^DROP | awk '\''{print $4}'\'' | sort -n'
alias oldunblock='iptables -D INPUT -j DROP -s '

# Show WHOIS summary with DNS and MX information
shwho() {
    [[ -z $1 || $1 =~ '-h' ]] && echo "Usage: shwho domain" && return 1

    local missing_deps=()
    command -v whois >/dev/null 2>&1 || missing_deps+=("whois")
    command -v dig >/dev/null 2>&1 || missing_deps+=("dig")

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required programs: ${missing_deps[*]}" >&2
        return 1
    fi

    local domain="$1"

    whois "$domain" | grep -E "^(Registrar:|Registrar Name:|Name Server:|DNSSEC:)"

    echo "$domain = $(dig +short "$domain" | tr '\n' ' ')"

    local MX=$(dig +short mx "$domain" | awk '{print $2}' | sed -e 's/\.$//')

    if [[ -n $MX ]]; then
        local IP=$(dig +short "$MX")
        if [[ $IP ]]; then
            echo "$MX = $IP"
            local PTR=$(dig +short -x "$IP" | sed -e 's/\.$//')
            [[ $PTR ]] && echo "$IP = $PTR"
        fi
    fi
}
