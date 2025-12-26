#!/bin/bash
# ServerStats - Web Collector
# Parses Nginx access logs for per-vhost statistics
# /usr/local/lib/serverstats/collectors/web.sh

source /usr/local/lib/serverstats/lib/common.sh

NGINX_LOG="${NGINX_LOG:-/var/log/nginx/access.log}"

collect_web() {
    local ymd="${1:-$(yesterday)}"
    local logdate=$(date -d "$ymd" "+%d/%b/%Y")

    log_info "Collecting web stats for $ymd (pattern: $logdate)"

    if [ ! -f "$NGINX_LOG" ]; then
        log_error "Nginx access log not found: $NGINX_LOG"
        return 1
    fi

    # Use awk to do all the parsing and aggregation in one pass
    grep "\[$logdate:" "$NGINX_LOG" 2>/dev/null | awk -v ymd="$ymd" '
    BEGIN { FS=" " }
    {
        vhost = $1
        ip = $2
        # Skip invalid vhosts
        if (vhost == "-" || vhost == "0.0.0.0" || vhost ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) next

        # Find status code and bytes
        status = 0
        bytes = 0
        for(i=1; i<=NF; i++) {
            if ($i ~ /^[0-9]{3}$/ && $(i+1) ~ /^[0-9]+$/) {
                status = $i
                bytes = $(i+1)
                break
            }
        }
        if (status == 0) next

        # Aggregate
        requests[vhost]++
        bytes_total[vhost] += bytes
        ips[vhost, ip] = 1

        status_class = int(status / 100)
        if (status_class == 2) s2xx[vhost]++
        else if (status_class == 3) s3xx[vhost]++
        else if (status_class == 4) s4xx[vhost]++
        else if (status_class == 5) s5xx[vhost]++
    }
    END {
        for (vhost in requests) {
            # Count unique IPs
            unique = 0
            for (key in ips) {
                split(key, parts, SUBSEP)
                if (parts[1] == vhost) unique++
            }
            printf "%s|%d|%d|%d|%d|%d|%d|%d\n", \
                vhost, requests[vhost], bytes_total[vhost]+0, \
                s2xx[vhost]+0, s3xx[vhost]+0, s4xx[vhost]+0, s5xx[vhost]+0, unique
        }
    }' | while IFS="|" read -r vhost requests bytes s2xx s3xx s4xx s5xx unique_ips; do
        db_upsert_web "$ymd" "$vhost" "$requests" "$bytes" "$s2xx" "$s3xx" "$s4xx" "$s5xx" "$unique_ips"
        log_debug "Web stats for $vhost: requests=$requests bytes=$bytes 2xx=$s2xx 5xx=$s5xx"
    done

    # Log summary
    local totals=$(db_web_total "$ymd")
    log_info "Web stats totals: $totals"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    collect_web "$1"
fi
