#!/bin/bash
# ServerStats - Daily Report Generator
# Creates formatted daily usage report
# /usr/local/lib/serverstats/reports/daily.sh

source /usr/local/lib/serverstats/lib/common.sh

generate_daily_report() {
    local ymd="${1:-$(yesterday)}"
    local hostname=$(hostname -f)

    # Get uptime for header
    local uptime=$(db_value "SELECT uptime_days FROM daily_system WHERE ymd='$ymd';")
    uptime=${uptime:-0}

    # Header
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
              SERVER USAGE REPORT - $hostname
              Period: $ymd (Daily)    Uptime: ${uptime} days
═══════════════════════════════════════════════════════════════════════════

EOF

    # Mail section
    report_mail "$ymd"

    # Spam section
    report_spam "$ymd"

    # Web section
    report_web "$ymd"

    # Network section
    report_network "$ymd"

    # System section
    report_system "$ymd"

    # Footer
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
  Generated: $(date "+%Y-%m-%d %H:%M %Z")    Data retention: 365 days
═══════════════════════════════════════════════════════════════════════════
EOF
}

report_mail() {
    local ymd=$1

    local row=$(db_query "SELECT sent, bounced, deferred, rejected, connections, auth_failures FROM daily_mail WHERE ymd='$ymd';")

    if [ -z "$row" ]; then
        cat << EOF
📧 MAIL DELIVERY
───────────────────────────────────────────────────────────────────────────
  No mail data for $ymd

EOF
        return
    fi

    IFS="|" read -r sent bounced deferred rejected connections auth_failures <<< "$row"

    # Get 7-day averages
    local avg_sent=$(db_mail_avg "sent" "$ymd")
    local avg_rejected=$(db_mail_avg "rejected" "$ymd")
    local avg_auth=$(db_mail_avg "auth_failures" "$ymd")

    cat << EOF
📧 MAIL DELIVERY                                          vs 7-day avg
───────────────────────────────────────────────────────────────────────────
  Sent:       $(printf "%4d" $sent)  $(pct_change $sent $avg_sent)       Bounced:     $(printf "%4d" $bounced)       Deferred:  $(printf "%4d" $deferred)
  Rejected:   $(printf "%4d" $rejected)  $(pct_change $rejected $avg_rejected)       Auth Fails:  $(printf "%4d" $auth_failures)  $(pct_change $auth_failures $avg_auth)       Connects: $(printf "%5d" $connections)

EOF
}

report_spam() {
    local ymd=$1

    local totals=$(db_query "SELECT COALESCE(SUM(inbox_count),0), COALESCE(SUM(junk_count),0), COALESCE(SUM(trash_count),0), COALESCE(SUM(train_good),0), COALESCE(SUM(train_spam),0) FROM daily_spam WHERE ymd='$ymd';")

    if [ -z "$totals" ] || [ "$totals" = "0|0|0|0|0" ]; then
        cat << EOF
🛡️ SPAM FILTERING
───────────────────────────────────────────────────────────────────────────
  No spam data for $ymd

EOF
        return
    fi

    IFS="|" read -r inbox junk trash train_good train_spam <<< "$totals"

    local total=$((inbox + junk + trash))
    local clean_pct=0
    local inbox_pct=0
    local junk_pct=0
    if [ $total -gt 0 ]; then
        clean_pct=$(echo "scale=1; $inbox * 100 / $total" | bc)
        inbox_pct=$clean_pct
        junk_pct=$(echo "scale=1; $junk * 100 / $total" | bc)
    fi

    cat << EOF
🛡️ SPAM FILTERING                                        Effectiveness: ${clean_pct}%
───────────────────────────────────────────────────────────────────────────
  Inbox:     $(printf "%4d" $inbox) (${inbox_pct}%)    Junk:      $(printf "%4d" $junk) (${junk_pct}%)    Trash:     $(printf "%4d" $trash)
  Training:  +$train_good good  -$train_spam spam

EOF

    # Top mailboxes by activity
    local top_mailboxes=$(db_query "SELECT mailbox, inbox_count+junk_count+trash_count as total,
        inbox_count, inbox_count+junk_count+trash_count as denom
        FROM daily_spam WHERE ymd='$ymd' ORDER BY total DESC LIMIT 5;")

    if [ -n "$top_mailboxes" ]; then
        echo "  Top Mailboxes:"
        echo "$top_mailboxes" | while IFS="|" read -r mailbox mtotal minbox mdenom; do
            local mpct=0
            [ "$mdenom" -gt 0 ] && mpct=$((minbox * 100 / mdenom))
            printf "    %-35s %3d msgs  %3d%% clean\n" "$mailbox" "$mtotal" "$mpct"
        done
        echo ""
    fi
}

report_web() {
    local ymd=$1

    local totals=$(db_query "SELECT COALESCE(SUM(requests),0), COALESCE(SUM(bytes_sent),0), COALESCE(SUM(status_2xx),0), COALESCE(SUM(status_5xx),0), COUNT(DISTINCT vhost) FROM daily_web WHERE ymd='$ymd';")

    if [ -z "$totals" ] || [ "${totals%%|*}" = "0" ]; then
        cat << EOF
🌐 WEB TRAFFIC
───────────────────────────────────────────────────────────────────────────
  No web data for $ymd

EOF
        return
    fi

    IFS="|" read -r requests bytes s2xx s5xx vhosts <<< "$totals"

    local bytes_human=$(human_bytes $bytes)
    local success_pct=0
    [ $requests -gt 0 ] && success_pct=$(echo "scale=1; $s2xx * 100 / $requests" | bc)

    cat << EOF
🌐 WEB TRAFFIC
───────────────────────────────────────────────────────────────────────────
  Requests:  $(printf "%6d" $requests)       Bandwidth:   $bytes_human       Vhosts: $vhosts
  Success:   $(printf "%6d" $s2xx) ($success_pct%)    Errors:      $(printf "%4d" $s5xx)

EOF

    # Top vhosts
    local top_vhosts=$(db_query "SELECT vhost, requests, bytes_sent FROM daily_web WHERE ymd='$ymd' ORDER BY requests DESC LIMIT 5;")

    if [ -n "$top_vhosts" ]; then
        echo "  Top Sites:"
        local max_req=$(echo "$top_vhosts" | head -1 | cut -d"|" -f2)
        echo "$top_vhosts" | while IFS="|" read -r vhost vreq vbytes; do
            local bar=$(bar_chart $vreq $max_req 20)
            printf "    %-35s %s %6d req  %s\n" "${vhost:0:35}" "$bar" "$vreq" "$(human_bytes $vbytes)"
        done
        echo ""
    fi
}

report_network() {
    local ymd=$1

    local rows=$(db_query "SELECT interface, rx_bytes, tx_bytes FROM daily_network WHERE ymd='$ymd';")

    if [ -z "$rows" ]; then
        cat << EOF
📊 NETWORK I/O
───────────────────────────────────────────────────────────────────────────
  No network data for $ymd

EOF
        return
    fi

    cat << EOF
📊 NETWORK I/O
───────────────────────────────────────────────────────────────────────────
EOF

    echo "$rows" | while IFS="|" read -r iface rx tx; do
        printf "  %-8s ↓ %-12s  ↑ %-12s\n" "$iface:" "$(human_bytes $rx)" "$(human_bytes $tx)"
    done
    echo ""
}

report_system() {
    local ymd=$1

    local row=$(db_query "SELECT hostname, disk_used_gb, disk_total_gb, disk_pct, mem_used_mb, mem_total_mb, load_1m, load_5m, load_15m, uptime_days FROM daily_system WHERE ymd='$ymd';")

    if [ -z "$row" ]; then
        cat << EOF
💾 SYSTEM RESOURCES
───────────────────────────────────────────────────────────────────────────
  No system data for $ymd

EOF
        return
    fi

    IFS="|" read -r hostname disk_used disk_total disk_pct mem_used mem_total load1 load5 load15 uptime <<< "$row"

    # Convert to integers for bar_chart
    local disk_pct_int=${disk_pct%.*}
    local disk_bar=$(bar_chart $disk_pct_int 100 20)
    local mem_pct=$((mem_used * 100 / mem_total))
    local mem_bar=$(bar_chart $mem_pct 100 20)

    cat << EOF
💾 SYSTEM RESOURCES                                       Uptime: ${uptime} days
───────────────────────────────────────────────────────────────────────────
  Disk:    $(printf "%5.0f" $disk_used) GB / $(printf "%5.0f" $disk_total) GB  $disk_bar  ${disk_pct}%
  Memory:  $(printf "%5d" $mem_used) MB / $(printf "%5d" $mem_total) MB  $mem_bar  ${mem_pct}%
  Load:    $load1, $load5, $load15

EOF
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    generate_daily_report "$1"
fi
