#!/bin/bash
# ServerStats - Weekly Report Generator
# Creates formatted weekly usage report with trends
# /usr/local/lib/serverstats/reports/weekly.sh

source /usr/local/lib/serverstats/lib/common.sh

generate_weekly_report() {
    local end_date="${1:-$(yesterday)}"
    local start_date=$(date -d "$end_date -6 days" +%Y-%m-%d)
    local prev_end=$(date -d "$start_date -1 day" +%Y-%m-%d)
    local prev_start=$(date -d "$prev_end -6 days" +%Y-%m-%d)
    local hostname=$(hostname -f)

    # Header
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
              WEEKLY SERVER USAGE REPORT - $hostname
              Period: $start_date to $end_date (7 days)
═══════════════════════════════════════════════════════════════════════════

EOF

    # Mail section
    report_mail_weekly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # Spam section
    report_spam_weekly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # Web section
    report_web_weekly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # Network section
    report_network_weekly "$start_date" "$end_date"

    # System section
    report_system_weekly "$start_date" "$end_date"

    # Daily breakdown
    report_daily_breakdown "$start_date" "$end_date"

    # Footer
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
  Generated: $(date "+%Y-%m-%d %H:%M %Z")    Data retention: 365 days
═══════════════════════════════════════════════════════════════════════════
EOF
}

report_mail_weekly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_week=$(db_query "SELECT COALESCE(SUM(sent),0), COALESCE(SUM(bounced),0), COALESCE(SUM(deferred),0), COALESCE(SUM(rejected),0), COALESCE(SUM(connections),0), COALESCE(SUM(auth_failures),0) FROM daily_mail WHERE ymd BETWEEN '$start' AND '$end';")
    local prev_week=$(db_query "SELECT COALESCE(SUM(sent),0), COALESCE(SUM(bounced),0), COALESCE(SUM(deferred),0), COALESCE(SUM(rejected),0), COALESCE(SUM(connections),0), COALESCE(SUM(auth_failures),0) FROM daily_mail WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    IFS="|" read -r sent bounced deferred rejected connections auth_failures <<< "$this_week"
    IFS="|" read -r p_sent p_bounced p_deferred p_rejected p_connections p_auth <<< "$prev_week"

    cat << EOF
📧 MAIL DELIVERY (Weekly Total)                           vs Previous Week
───────────────────────────────────────────────────────────────────────────
  Sent:       $(printf "%5d" $sent)  $(pct_change $sent $p_sent)       Bounced:     $(printf "%5d" $bounced)  $(pct_change $bounced $p_bounced)
  Rejected:   $(printf "%5d" $rejected)  $(pct_change $rejected $p_rejected)       Auth Fails:  $(printf "%5d" $auth_failures)  $(pct_change $auth_failures $p_auth)
  Deferred:   $(printf "%5d" $deferred)                   Connects:    $(printf "%5d" $connections)

EOF
}

report_spam_weekly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_week=$(db_query "SELECT COALESCE(SUM(inbox_count),0), COALESCE(SUM(junk_count),0), COALESCE(SUM(trash_count),0), COALESCE(SUM(train_good),0), COALESCE(SUM(train_spam),0) FROM daily_spam WHERE ymd BETWEEN '$start' AND '$end';")
    local prev_week=$(db_query "SELECT COALESCE(SUM(inbox_count),0), COALESCE(SUM(junk_count),0), COALESCE(SUM(trash_count),0) FROM daily_spam WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    IFS="|" read -r inbox junk trash train_good train_spam <<< "$this_week"
    IFS="|" read -r p_inbox p_junk p_trash <<< "$prev_week"

    local total=$((inbox + junk + trash))
    local p_total=$((p_inbox + p_junk + p_trash))
    local clean_pct=0
    [ $total -gt 0 ] && clean_pct=$(echo "scale=1; $inbox * 100 / $total" | bc)

    cat << EOF
🛡️ SPAM FILTERING (Weekly Total)                         Effectiveness: ${clean_pct}%
───────────────────────────────────────────────────────────────────────────
  Inbox:      $(printf "%5d" $inbox)  $(pct_change $inbox $p_inbox)       Junk:        $(printf "%5d" $junk)  $(pct_change $junk $p_junk)
  Trash:      $(printf "%5d" $trash)                   Training:    +$train_good good / -$train_spam spam
  Total Msgs: $(printf "%5d" $total)  $(pct_change $total $p_total)

EOF

    # Top mailboxes for the week
    local top_mailboxes=$(db_query "SELECT mailbox, SUM(inbox_count+junk_count+trash_count) as total,
        SUM(inbox_count) as inbox, SUM(junk_count) as junk
        FROM daily_spam WHERE ymd BETWEEN '$start' AND '$end'
        GROUP BY mailbox ORDER BY total DESC LIMIT 5;")

    if [ -n "$top_mailboxes" ]; then
        echo "  Top Mailboxes This Week:"
        echo "$top_mailboxes" | while IFS="|" read -r mailbox mtotal minbox mjunk; do
            local mpct=0
            [ "$mtotal" -gt 0 ] && mpct=$((minbox * 100 / mtotal))
            printf "    %-35s %4d msgs  %3d%% clean  %3d spam\n" "$mailbox" "$mtotal" "$mpct" "$mjunk"
        done
        echo ""
    fi
}

report_web_weekly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_week=$(db_query "SELECT COALESCE(SUM(requests),0), COALESCE(SUM(bytes_sent),0), COALESCE(SUM(status_2xx),0), COALESCE(SUM(status_5xx),0) FROM daily_web WHERE ymd BETWEEN '$start' AND '$end';")
    local prev_week=$(db_query "SELECT COALESCE(SUM(requests),0), COALESCE(SUM(bytes_sent),0) FROM daily_web WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    IFS="|" read -r requests bytes s2xx s5xx <<< "$this_week"
    IFS="|" read -r p_requests p_bytes <<< "$prev_week"

    local bytes_human=$(human_bytes $bytes)
    local p_bytes_human=$(human_bytes $p_bytes)
    local success_pct=0
    [ $requests -gt 0 ] && success_pct=$(echo "scale=1; $s2xx * 100 / $requests" | bc)

    cat << EOF
🌐 WEB TRAFFIC (Weekly Total)                             vs Previous Week
───────────────────────────────────────────────────────────────────────────
  Requests:   $(printf "%7d" $requests)  $(pct_change $requests $p_requests)     Bandwidth:  $bytes_human  $(pct_change $bytes $p_bytes)
  Success:    $(printf "%7d" $s2xx) ($success_pct%)          Errors:     $(printf "%5d" $s5xx)

EOF

    # Top vhosts for the week
    local top_vhosts=$(db_query "SELECT vhost, SUM(requests) as req, SUM(bytes_sent) as bytes
        FROM daily_web WHERE ymd BETWEEN '$start' AND '$end'
        GROUP BY vhost ORDER BY req DESC LIMIT 10;")

    if [ -n "$top_vhosts" ]; then
        echo "  Top 10 Sites This Week:"
        local max_req=$(echo "$top_vhosts" | head -1 | cut -d"|" -f2)
        echo "$top_vhosts" | while IFS="|" read -r vhost vreq vbytes; do
            local bar=$(bar_chart $vreq $max_req 15)
            printf "    %-30s %s %7d req  %s\n" "${vhost:0:30}" "$bar" "$vreq" "$(human_bytes $vbytes)"
        done
        echo ""
    fi
}

report_network_weekly() {
    local start=$1 end=$2

    local totals=$(db_query "SELECT interface, SUM(rx_bytes), SUM(tx_bytes) FROM daily_network WHERE ymd BETWEEN '$start' AND '$end' GROUP BY interface;")

    if [ -z "$totals" ]; then
        cat << EOF
📊 NETWORK I/O (Weekly Total)
───────────────────────────────────────────────────────────────────────────
  No network data for this period

EOF
        return
    fi

    cat << EOF
📊 NETWORK I/O (Weekly Total)
───────────────────────────────────────────────────────────────────────────
EOF

    echo "$totals" | while IFS="|" read -r iface rx tx; do
        printf "  %-8s ↓ %-12s  ↑ %-12s  Total: %s\n" "$iface:" "$(human_bytes $rx)" "$(human_bytes $tx)" "$(human_bytes $((rx + tx)))"
    done
    echo ""
}

report_system_weekly() {
    local start=$1 end=$2

    # Get average and latest system stats
    local avg=$(db_query "SELECT ROUND(AVG(disk_pct),1), ROUND(AVG(mem_used_mb),0), ROUND(AVG(load_1m),2) FROM daily_system WHERE ymd BETWEEN '$start' AND '$end';")
    local latest=$(db_query "SELECT disk_pct, mem_used_mb, mem_total_mb, uptime_days FROM daily_system WHERE ymd='$end';")

    if [ -z "$latest" ]; then
        cat << EOF
💾 SYSTEM RESOURCES
───────────────────────────────────────────────────────────────────────────
  No system data for this period

EOF
        return
    fi

    IFS="|" read -r avg_disk avg_mem avg_load <<< "$avg"
    IFS="|" read -r disk_pct mem_used mem_total uptime <<< "$latest"

    cat << EOF
💾 SYSTEM RESOURCES (Weekly Average)                      Current
───────────────────────────────────────────────────────────────────────────
  Avg Disk:   ${avg_disk}%                                Now: ${disk_pct}%
  Avg Memory: ${avg_mem} MB                              Now: ${mem_used} MB / ${mem_total} MB
  Avg Load:   ${avg_load}                                Uptime: ${uptime} days

EOF
}

report_daily_breakdown() {
    local start=$1 end=$2

    cat << EOF
📅 DAILY BREAKDOWN
───────────────────────────────────────────────────────────────────────────
  Date        Mail Sent  Spam/Ham    Web Reqs    Bandwidth
EOF

    db_query "SELECT
        m.ymd,
        COALESCE(m.sent, 0),
        COALESCE(s.junk, 0) || '/' || COALESCE(s.inbox, 0),
        COALESCE(w.requests, 0),
        COALESCE(w.bytes, 0)
    FROM daily_mail m
    LEFT JOIN (SELECT ymd, SUM(junk_count) as junk, SUM(inbox_count) as inbox FROM daily_spam GROUP BY ymd) s ON m.ymd = s.ymd
    LEFT JOIN (SELECT ymd, SUM(requests) as requests, SUM(bytes_sent) as bytes FROM daily_web GROUP BY ymd) w ON m.ymd = w.ymd
    WHERE m.ymd BETWEEN '$start' AND '$end'
    ORDER BY m.ymd;" | while IFS="|" read -r ymd sent spam_ham requests bytes; do
        printf "  %-10s %9d  %9s  %10d    %s\n" "$ymd" "$sent" "$spam_ham" "$requests" "$(human_bytes $bytes)"
    done

    echo ""
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    generate_weekly_report "$1"
fi
