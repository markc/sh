#!/bin/bash
# ServerStats - Common library functions
# /usr/local/lib/serverstats/lib/common.sh

# Configuration
export STATS_DB="/var/lib/serverstats/stats.db"
export STATS_LIB="/usr/local/lib/serverstats"
export STATS_LOG="/var/log/serverstats.log"
export REPORT_EMAIL="markc@renta.net"
export HOSTNAME=$(hostname -f)
export TZ="Australia/Brisbane"

# Log paths
export MAIL_LOG="/var/log/mail.log"
export DOVECOT_DEBUG_LOG="/var/log/dovecot-debug.log"
export WEB_LOG_DIR="/srv"
export VNSTAT_DB="/var/lib/vnstat"

# Date helpers
yesterday() {
    date -d "yesterday" +%Y-%m-%d
}

today() {
    date +%Y-%m-%d
}

week_ago() {
    date -d "7 days ago" +%Y-%m-%d
}

month_ago() {
    date -d "30 days ago" +%Y-%m-%d
}

# Get date for log grep (e.g., "Dec 25")
log_date() {
    local ymd="${1:-$(yesterday)}"
    date -d "$ymd" "+%b %e" | sed "s/  / /"
}

# Logging
log_info() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] INFO: $*" >> "$STATS_LOG"
}

log_error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERROR: $*" >> "$STATS_LOG"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] DEBUG: $*" >> "$STATS_LOG"
    fi
}

# Human-readable sizes
human_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes/1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=1; $bytes/1024" | bc) KB"
    else
        echo "$bytes B"
    fi
}

# Bar chart helper (20 chars wide)
bar_chart() {
    local value=$1
    local max=$2
    local width=${3:-20}
    
    if [ "$max" -eq 0 ]; then
        printf "%${width}s" ""
        return
    fi
    
    local filled=$(( value * width / max ))
    local empty=$(( width - filled ))
    
    printf "%s%s" "$(printf "█%.0s" $(seq 1 $filled 2>/dev/null))" "$(printf "░%.0s" $(seq 1 $empty 2>/dev/null))"
}

# Percentage with arrow vs previous
pct_change() {
    local current=$1
    local previous=$2
    
    if [ "$previous" -eq 0 ]; then
        echo "━ new"
        return
    fi
    
    local diff=$(( current - previous ))
    local pct=$(echo "scale=0; $diff * 100 / $previous" | bc)
    
    if [ "$diff" -gt 0 ]; then
        echo "▲ +${pct}%"
    elif [ "$diff" -lt 0 ]; then
        echo "▼ ${pct}%"
    else
        echo "━ 0%"
    fi
}

# Source db helpers
source "${STATS_LIB}/lib/db.sh"
