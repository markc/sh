#!/bin/bash
# ServerStats - System Collector
# Collects disk, memory, load, and uptime statistics
# /usr/local/lib/serverstats/collectors/system.sh

source /usr/local/lib/serverstats/lib/common.sh

collect_system() {
    local ymd="${1:-$(today)}"

    log_info "Collecting system stats for $ymd"

    local hostname=$(hostname -f)

    # Disk usage (root filesystem)
    local disk_info=$(df -BG / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}' | sed 's/G//')
    local disk_used=$(echo "$disk_info" | awk '{print $3}' | sed 's/G//')
    local disk_pct=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')

    # Memory usage
    local mem_info=$(free -m | grep "^Mem:")
    local mem_total=$(echo "$mem_info" | awk '{print $2}')
    local mem_used=$(echo "$mem_info" | awk '{print $3}')

    # Swap usage
    local swap_info=$(free -m | grep "^Swap:")
    local swap_used=$(echo "$swap_info" | awk '{print $3}')
    [ -z "$swap_used" ] && swap_used=0

    # Load averages
    local load_info=$(cat /proc/loadavg)
    local load_1m=$(echo "$load_info" | awk '{print $1}')
    local load_5m=$(echo "$load_info" | awk '{print $2}')
    local load_15m=$(echo "$load_info" | awk '{print $3}')

    # Uptime in days
    local uptime_secs=$(cat /proc/uptime | awk '{print int($1)}')
    local uptime_days=$((uptime_secs / 86400))

    # Process count
    local processes=$(ps aux | wc -l)

    db_upsert_system "$ymd" "$hostname" "$disk_used" "$disk_total" "$disk_pct" \
        "$mem_used" "$mem_total" "$swap_used" \
        "$load_1m" "$load_5m" "$load_15m" "$uptime_days" "$processes"

    log_info "System stats: disk=${disk_used}/${disk_total}GB (${disk_pct}%) mem=${mem_used}/${mem_total}MB load=$load_1m uptime=${uptime_days}d"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    collect_system "$1"
fi
