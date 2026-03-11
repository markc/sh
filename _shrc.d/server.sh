# Server administration: DKIM, user management, vhost navigation
# Source from ~/.myrc on mail/web servers: source ~/.rc/_shrc.d/server.sh

# Navigate to vhost directories
go2() {
    if [[ $1 =~ "@" ]]; then
        cd /srv/${1#*@}*/msg/*${1%@*}
    else
        cd /srv/$1*/web/app
    fi
}

# Show all vhosts on server
# Usage: shhost [pattern]
shhost() {
    if [[ -n $1 ]]; then
        /bin/ls -1 /srv/ | grep "$1"
    else
        /bin/ls -1 /srv/
    fi
}

# Create new user (username, password, comment, homedir)
newuser() {
    [[ -z $1 ]] && echo "Usage: newuser <username> [password] [comment] [homedir]" && return 1
    local user=$1 pass=${2:-$(newpw)} comment=$3 homedir=$4 opts=()
    [[ -n $comment ]] && opts+=(-c "$comment")
    [[ -n $homedir ]] && opts+=(-d "$homedir")
    useradd -m "${opts[@]}" "$user" && echo "$user:$pass" | chpasswd && echo "✅ User: $user | Pass: $pass"
}

# Setup chroot SFTP for existing user (for backup servers)
chrootuser() {
    [[ -z $1 ]] && echo "Usage: chrootuser <username>" && return 1
    local user=$1 home=$(getent passwd "$user" | cut -d: -f6)
    [[ -z $home ]] && echo "❌ User $user not found" && return 1
    chown root:root "$home" && chmod 755 "$home" && \
    mkdir -p "$home/data" && chown "$user:$user" "$home/data" && \
    echo "✅ Chroot setup: $home (data/ writable by $user)"
}

# ========== DKIM MANAGEMENT ==========

# Show DKIM keys - usage: shdkim [domain|--all]
shdkim() {
    local DKIM_DIR="/etc/opendkim/keys"

    if [[ $1 == "--all" || -z $1 ]]; then
        echo "=== DKIM Keys Available ==="
        if [[ -d $DKIM_DIR ]]; then
            for domain_dir in "$DKIM_DIR"/*/ ; do
                [[ -d $domain_dir ]] || continue
                local domain=$(basename "$domain_dir")
                local selector="mail"
                if [[ -f "$domain_dir/${selector}.txt" ]]; then
                    echo "✓ $domain (selector: $selector)"
                elif [[ -f "$domain_dir/${selector}.private" ]]; then
                    echo "⚠ $domain (selector: $selector) - private key exists but no TXT record"
                fi
            done
        else
            echo "Error: DKIM directory not found: $DKIM_DIR"
        fi
    else
        local domain="$1"
        local selector="${2:-mail}"
        local key_dir="$DKIM_DIR/$domain"

        if [[ -f "$key_dir/${selector}.txt" ]]; then
            local record_name=$(head -1 "$key_dir/${selector}.txt" | awk '{print $1}')

            local record_value=$(cat "$key_dir/${selector}.txt" | \
                grep -v "^#" | \
                tr -d '\t\n\r"() ' | \
                sed -e 's/^[^v]*IN.*TXT//' -e 's/;-.*$//')

            if [[ "$record_name" == "${selector}._domainkey" ]]; then
                record_name="${selector}._domainkey.${domain}"
            fi

            echo "$record_name"
            echo "$record_value"
        else
            echo "No match for '$domain'"
            return 1
        fi
    fi
}

# Add new DKIM key - usage: adddkim <domain> [selector]
adddkim() {
    [[ -z $1 ]] && echo "Usage: adddkim <domain> [selector]" && return 1

    local domain="$1"
    local selector="${2:-mail}"
    local DKIM_DIR="/etc/opendkim/keys"
    local key_dir="$DKIM_DIR/$domain"

    if ! command -v opendkim-genkey >/dev/null 2>&1; then
        echo "Error: opendkim-genkey not found. Install opendkim-tools package."
        return 1
    fi

    echo "=== Adding DKIM for $domain ==="

    $SUDO mkdir -p "$key_dir"

    echo "Generating DKIM key (selector: $selector)..."
    cd "$key_dir"
    $SUDO opendkim-genkey -b 2048 -d "$domain" -s "$selector"

    $SUDO chown -R opendkim:opendkim "$key_dir"
    $SUDO chmod 700 "$key_dir"
    $SUDO chmod 600 "$key_dir/${selector}.private"
    $SUDO chmod 600 "$key_dir/${selector}.txt"

    local key_id=$(date +%s)

    echo "Updating KeyTable..."
    if ! grep -q "^${key_id}" /etc/opendkim/KeyTable 2>/dev/null; then
        echo "${key_id}     ${domain}:${selector}:/etc/opendkim/keys/${domain}/${selector}.private" | $SUDO tee -a /etc/opendkim/KeyTable >/dev/null
    fi

    echo "Updating SigningTable..."
    if ! grep -q "*@${domain}" /etc/opendkim/SigningTable 2>/dev/null; then
        echo "*@${domain}       ${key_id}" | $SUDO tee -a /etc/opendkim/SigningTable >/dev/null
    fi

    echo "Updating TrustedHosts..."
    if ! grep -q "^${domain}$" /etc/opendkim/TrustedHosts 2>/dev/null; then
        {
            echo "${domain}"
            echo "*.${domain}"
        } | $SUDO tee -a /etc/opendkim/TrustedHosts >/dev/null
    fi

    echo "Reloading OpenDKIM..."
    sc reload opendkim

    echo
    echo "✓ DKIM key added for $domain"
    echo
    echo "Add this DNS TXT record:"
    cat "$key_dir/${selector}.txt"
}

# Change/rotate DKIM key - usage: chdkim <domain> [selector]
chdkim() {
    [[ -z $1 ]] && echo "Usage: chdkim <domain> [selector]" && return 1

    local domain="$1"
    local selector="${2:-mail}"
    local DKIM_DIR="/etc/opendkim/keys"
    local key_dir="$DKIM_DIR/$domain"

    echo "=== Rotating DKIM for $domain ==="

    if [[ -f "$key_dir/${selector}.private" ]]; then
        local backup_date=$(date +%Y%m%d-%H%M%S)
        echo "Backing up old key to ${selector}.private.${backup_date}"
        $SUDO mv "$key_dir/${selector}.private" "$key_dir/${selector}.private.${backup_date}"
        $SUDO mv "$key_dir/${selector}.txt" "$key_dir/${selector}.txt.${backup_date}"
    fi

    echo "Generating new DKIM key..."
    cd "$key_dir"
    $SUDO opendkim-genkey -b 2048 -d "$domain" -s "$selector"

    $SUDO chown -R opendkim:opendkim "$key_dir"
    $SUDO chmod 700 "$key_dir"
    $SUDO chmod 600 "$key_dir/${selector}.private"
    $SUDO chmod 600 "$key_dir/${selector}.txt"

    echo "Reloading OpenDKIM..."
    sc reload opendkim

    echo
    echo "✓ DKIM key rotated for $domain"
    echo
    echo "Update DNS TXT record with:"
    cat "$key_dir/${selector}.txt"
}

# Delete DKIM key - usage: deldkim <domain>
deldkim() {
    [[ -z $1 ]] && echo "Usage: deldkim <domain>" && return 1

    local domain="$1"
    local DKIM_DIR="/etc/opendkim/keys"
    local key_dir="$DKIM_DIR/$domain"

    echo "=== Removing DKIM for $domain ==="

    echo "Removing from KeyTable..."
    $SUDO sed -i "/[[:space:]]${domain}:mail:/d" /etc/opendkim/KeyTable

    echo "Removing from SigningTable..."
    $SUDO sed -i "/\*@${domain}[[:space:]]/d" /etc/opendkim/SigningTable

    echo "Removing from TrustedHosts..."
    $SUDO sed -i "/^${domain}$/d" /etc/opendkim/TrustedHosts
    $SUDO sed -i "/^\*\.${domain}$/d" /etc/opendkim/TrustedHosts

    if [[ -d "$key_dir" ]]; then
        local archive_date=$(date +%Y%m%d-%H%M%S)
        echo "Archiving key directory to ${key_dir}.deleted.${archive_date}"
        $SUDO mv "$key_dir" "${key_dir}.deleted.${archive_date}"
    fi

    echo "Reloading OpenDKIM..."
    sc reload opendkim

    echo
    echo "✓ DKIM removed for $domain"
    echo "  Remove DNS TXT record: ${domain}._domainkey.${domain}"
}
