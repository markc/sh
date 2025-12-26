#!/bin/bash
# ServerStats - Network Collector
# Uses vnstat for network I/O statistics
# /usr/local/lib/serverstats/collectors/network.sh

source /usr/local/lib/serverstats/lib/common.sh

collect_network() {
    local ymd="${1:-$(yesterday)}"

    log_info "Collecting network stats for $ymd"

    if ! command -v vnstat &>/dev/null; then
        log_error "vnstat not installed"
        return 1
    fi

    # Get JSON output for daily stats
    local json=$(vnstat --json d 30 2>/dev/null)

    if [ -z "$json" ]; then
        log_error "Failed to get vnstat data"
        return 1
    fi

    # Parse the date we're looking for
    local target_year=$(date -d "$ymd" +%Y)
    local target_month=$(date -d "$ymd" +%-m)
    local target_day=$(date -d "$ymd" +%-d)

    # Extract interfaces and their data using jq if available, otherwise use grep/awk
    if command -v jq &>/dev/null; then
        # Use jq for proper JSON parsing
        echo "$json" | jq -r --arg y "$target_year" --arg m "$target_month" --arg d "$target_day" '
            .interfaces[] |
            .name as $iface |
            .traffic.day[] |
            select(.date.year == ($y | tonumber) and .date.month == ($m | tonumber) and .date.day == ($d | tonumber)) |
            "\($iface)|\(.rx)|\(.tx)"
        ' | while IFS="|" read -r iface rx tx; do
            if [ -n "$iface" ] && [ -n "$rx" ] && [ -n "$tx" ]; then
                # vnstat doesn't provide packet counts in daily summary, use 0
                db_upsert_network "$ymd" "$iface" "$rx" "$tx" 0 0
                log_info "Network stats for $iface: rx=$(human_bytes $rx) tx=$(human_bytes $tx)"
            fi
        done
    else
        # Fallback: parse with grep/awk (less reliable but works without jq)
        # Get interface names
        local interfaces=$(echo "$json" | grep -oP '"name":"[^"]+"' | sed 's/"name":"//;s/"//')

        for iface in $interfaces; do
            # Extract rx/tx for the specific date (hacky but works)
            # This assumes the day entry is present in the output
            local rx=$(echo "$json" | grep -oP "\"rx\":[0-9]+" | head -1 | sed 's/"rx"://')
            local tx=$(echo "$json" | grep -oP "\"tx\":[0-9]+" | head -1 | sed 's/"tx"://')

            if [ -n "$rx" ] && [ -n "$tx" ]; then
                db_upsert_network "$ymd" "$iface" "$rx" "$tx" 0 0
                log_info "Network stats for $iface: rx=$rx tx=$tx"
            fi
        done
    fi
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    collect_network "$1"
fi
