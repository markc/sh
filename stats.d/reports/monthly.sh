#!/bin/bash
# ServerStats - Monthly Report Generator
# Creates formatted monthly usage report with trends
# /usr/local/lib/serverstats/reports/monthly.sh

source /usr/local/lib/serverstats/lib/common.sh

generate_monthly_report() {
    # Default to last month
    local target_month="${1:-$(date -d "last month" +%Y-%m)}"
    local start_date="${target_month}-01"
    local end_date=$(date -d "$start_date +1 month -1 day" +%Y-%m-%d)
    local prev_month=$(date -d "$start_date -1 month" +%Y-%m)
    local prev_start="${prev_month}-01"
    local prev_end=$(date -d "$prev_start +1 month -1 day" +%Y-%m-%d)
    local hostname=$(hostname -f)
    local month_name=$(date -d "$start_date" +"%B %Y")

    # Header
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
              MONTHLY SERVER USAGE REPORT - $hostname
              Period: $month_name ($start_date to $end_date)
═══════════════════════════════════════════════════════════════════════════

EOF

    # Mail section
    report_mail_monthly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # Spam section
    report_spam_monthly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # Web section
    report_web_monthly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # Network section
    report_network_monthly "$start_date" "$end_date" "$prev_start" "$prev_end"

    # System section
    report_system_monthly "$start_date" "$end_date"

    # Weekly breakdown
    report_weekly_breakdown "$start_date" "$end_date"

    # Footer
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
  Generated: $(date "+%Y-%m-%d %H:%M %Z")    Data retention: 365 days
═══════════════════════════════════════════════════════════════════════════
EOF
}

report_mail_monthly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_month=$(db_query "SELECT COALESCE(SUM(sent),0), COALESCE(SUM(bounced),0), COALESCE(SUM(deferred),0), COALESCE(SUM(rejected),0), COALESCE(SUM(connections),0), COALESCE(SUM(auth_failures),0), COUNT(*) FROM daily_mail WHERE ymd BETWEEN '$start' AND '$end';")
    local prev_month=$(db_query "SELECT COALESCE(SUM(sent),0), COALESCE(SUM(bounced),0), COALESCE(SUM(deferred),0), COALESCE(SUM(rejected),0), COALESCE(SUM(connections),0), COALESCE(SUM(auth_failures),0) FROM daily_mail WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    IFS="|" read -r sent bounced deferred rejected connections auth_failures days <<< "$this_month"
    IFS="|" read -r p_sent p_bounced p_deferred p_rejected p_connections p_auth <<< "$prev_month"

    local daily_avg=$((sent / (days > 0 ? days : 1)))

    cat << EOF
📧 MAIL DELIVERY (Monthly Total)                          vs Previous Month
───────────────────────────────────────────────────────────────────────────
  Sent:        $(printf "%6d" $sent)  $(pct_change $sent $p_sent)       Daily Avg:   $(printf "%5d" $daily_avg)
  Bounced:     $(printf "%6d" $bounced)  $(pct_change $bounced $p_bounced)       Rejected:    $(printf "%5d" $rejected)  $(pct_change $rejected $p_rejected)
  Auth Fails:  $(printf "%6d" $auth_failures)  $(pct_change $auth_failures $p_auth)       Connections: $(printf "%5d" $connections)

EOF
}

report_spam_monthly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_month=$(db_query "SELECT COALESCE(SUM(inbox_count),0), COALESCE(SUM(junk_count),0), COALESCE(SUM(trash_count),0), COALESCE(SUM(train_good),0), COALESCE(SUM(train_spam),0), COUNT(DISTINCT mailbox) FROM daily_spam WHERE ymd BETWEEN '$start' AND '$end';")
    local prev_month=$(db_query "SELECT COALESCE(SUM(inbox_count),0), COALESCE(SUM(junk_count),0), COALESCE(SUM(trash_count),0) FROM daily_spam WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    IFS="|" read -r inbox junk trash train_good train_spam mailboxes <<< "$this_month"
    IFS="|" read -r p_inbox p_junk p_trash <<< "$prev_month"

    local total=$((inbox + junk + trash))
    local p_total=$((p_inbox + p_junk + p_trash))
    local clean_pct=0
    local spam_pct=0
    if [ $total -gt 0 ]; then
        clean_pct=$(echo "scale=1; $inbox * 100 / $total" | bc)
        spam_pct=$(echo "scale=1; $junk * 100 / $total" | bc)
    fi

    cat << EOF
🛡️ SPAM FILTERING (Monthly Total)                        Effectiveness: ${clean_pct}%
───────────────────────────────────────────────────────────────────────────
  Total Msgs:  $(printf "%6d" $total)  $(pct_change $total $p_total)       Active Mailboxes: $mailboxes
  Clean:       $(printf "%6d" $inbox) (${clean_pct}%)        Spam Rate: ${spam_pct}%
  Junk:        $(printf "%6d" $junk)  $(pct_change $junk $p_junk)       Training: +$train_good / -$train_spam

EOF

    # Top 10 mailboxes for the month
    local top_mailboxes=$(db_query "SELECT mailbox, SUM(inbox_count+junk_count+trash_count) as total,
        SUM(inbox_count) as inbox, SUM(junk_count) as junk
        FROM daily_spam WHERE ymd BETWEEN '$start' AND '$end'
        GROUP BY mailbox ORDER BY total DESC LIMIT 10;")

    if [ -n "$top_mailboxes" ]; then
        echo "  Top 10 Mailboxes:"
        echo "$top_mailboxes" | while IFS="|" read -r mailbox mtotal minbox mjunk; do
            local mpct=0
            [ "$mtotal" -gt 0 ] && mpct=$((minbox * 100 / mtotal))
            printf "    %-35s %5d msgs  %3d%% clean\n" "$mailbox" "$mtotal" "$mpct"
        done
        echo ""
    fi
}

report_web_monthly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_month=$(db_query "SELECT COALESCE(SUM(requests),0), COALESCE(SUM(bytes_sent),0), COALESCE(SUM(status_2xx),0), COALESCE(SUM(status_5xx),0), COUNT(DISTINCT vhost) FROM daily_web WHERE ymd BETWEEN '$start' AND '$end';")
    local prev_month=$(db_query "SELECT COALESCE(SUM(requests),0), COALESCE(SUM(bytes_sent),0) FROM daily_web WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    IFS="|" read -r requests bytes s2xx s5xx vhosts <<< "$this_month"
    IFS="|" read -r p_requests p_bytes <<< "$prev_month"

    local bytes_human=$(human_bytes $bytes)
    local success_pct=0
    [ $requests -gt 0 ] && success_pct=$(echo "scale=1; $s2xx * 100 / $requests" | bc)

    cat << EOF
🌐 WEB TRAFFIC (Monthly Total)                            vs Previous Month
───────────────────────────────────────────────────────────────────────────
  Requests:    $(printf "%8d" $requests)  $(pct_change $requests $p_requests)   Active Vhosts: $vhosts
  Bandwidth:   $bytes_human  $(pct_change $bytes $p_bytes)
  Success:     $(printf "%8d" $s2xx) ($success_pct%)     Errors: $(printf "%6d" $s5xx)

EOF

    # Top 15 vhosts for the month
    local top_vhosts=$(db_query "SELECT vhost, SUM(requests) as req, SUM(bytes_sent) as bytes
        FROM daily_web WHERE ymd BETWEEN '$start' AND '$end'
        GROUP BY vhost ORDER BY req DESC LIMIT 15;")

    if [ -n "$top_vhosts" ]; then
        echo "  Top 15 Sites:"
        local max_req=$(echo "$top_vhosts" | head -1 | cut -d"|" -f2)
        echo "$top_vhosts" | while IFS="|" read -r vhost vreq vbytes; do
            local bar=$(bar_chart $vreq $max_req 12)
            printf "    %-28s %s %8d req  %s\n" "${vhost:0:28}" "$bar" "$vreq" "$(human_bytes $vbytes)"
        done
        echo ""
    fi
}

report_network_monthly() {
    local start=$1 end=$2 prev_start=$3 prev_end=$4

    local this_month=$(db_query "SELECT interface, SUM(rx_bytes), SUM(tx_bytes) FROM daily_network WHERE ymd BETWEEN '$start' AND '$end' GROUP BY interface;")
    local prev_totals=$(db_query "SELECT SUM(rx_bytes), SUM(tx_bytes) FROM daily_network WHERE ymd BETWEEN '$prev_start' AND '$prev_end';")

    if [ -z "$this_month" ]; then
        cat << EOF
📊 NETWORK I/O (Monthly Total)
───────────────────────────────────────────────────────────────────────────
  No network data for this period

EOF
        return
    fi

    IFS="|" read -r p_rx p_tx <<< "$prev_totals"
    p_rx=${p_rx:-0}
    p_tx=${p_tx:-0}

    cat << EOF
📊 NETWORK I/O (Monthly Total)                            vs Previous Month
───────────────────────────────────────────────────────────────────────────
EOF

    local total_rx=0 total_tx=0
    echo "$this_month" | while IFS="|" read -r iface rx tx; do
        printf "  %-8s ↓ %-12s  ↑ %-12s\n" "$iface:" "$(human_bytes $rx)" "$(human_bytes $tx)"
    done

    # Get totals for comparison
    local totals=$(db_query "SELECT SUM(rx_bytes), SUM(tx_bytes) FROM daily_network WHERE ymd BETWEEN '$start' AND '$end';")
    IFS="|" read -r total_rx total_tx <<< "$totals"
    local grand_total=$((total_rx + total_tx))
    local p_grand=$((p_rx + p_tx))

    echo ""
    printf "  Total:   %s  %s\n" "$(human_bytes $grand_total)" "$(pct_change $grand_total $p_grand)"
    echo ""
}

report_system_monthly() {
    local start=$1 end=$2

    # Get min/max/avg system stats
    local stats=$(db_query "SELECT
        ROUND(MIN(disk_pct),1), ROUND(MAX(disk_pct),1), ROUND(AVG(disk_pct),1),
        MIN(mem_used_mb), MAX(mem_used_mb), ROUND(AVG(mem_used_mb),0),
        ROUND(MIN(load_1m),2), ROUND(MAX(load_1m),2), ROUND(AVG(load_1m),2)
        FROM daily_system WHERE ymd BETWEEN '$start' AND '$end';")

    if [ -z "$stats" ]; then
        cat << EOF
💾 SYSTEM RESOURCES (Monthly Summary)
───────────────────────────────────────────────────────────────────────────
  No system data for this period

EOF
        return
    fi

    IFS="|" read -r disk_min disk_max disk_avg mem_min mem_max mem_avg load_min load_max load_avg <<< "$stats"

    cat << EOF
💾 SYSTEM RESOURCES (Monthly Summary)
───────────────────────────────────────────────────────────────────────────
                    Min         Max         Avg
  Disk Usage:       ${disk_min}%       ${disk_max}%       ${disk_avg}%
  Memory (MB):      ${mem_min}       ${mem_max}       ${mem_avg}
  Load Average:     ${load_min}        ${load_max}        ${load_avg}

EOF
}

report_weekly_breakdown() {
    local start=$1 end=$2

    cat << EOF
📅 WEEKLY BREAKDOWN
───────────────────────────────────────────────────────────────────────────
  Week              Mail Sent    Spam     Web Reqs     Bandwidth
EOF

    # Generate week ranges and stats
    local week_start="$start"
    local week_num=1

    while [[ "$week_start" < "$end" || "$week_start" == "$end" ]]; do
        local week_end=$(date -d "$week_start +6 days" +%Y-%m-%d)
        # Don't go past end of month
        [[ "$week_end" > "$end" ]] && week_end="$end"

        local stats=$(db_query "SELECT
            COALESCE((SELECT SUM(sent) FROM daily_mail WHERE ymd BETWEEN '$week_start' AND '$week_end'), 0),
            COALESCE((SELECT SUM(junk_count) FROM daily_spam WHERE ymd BETWEEN '$week_start' AND '$week_end'), 0),
            COALESCE((SELECT SUM(requests) FROM daily_web WHERE ymd BETWEEN '$week_start' AND '$week_end'), 0),
            COALESCE((SELECT SUM(bytes_sent) FROM daily_web WHERE ymd BETWEEN '$week_start' AND '$week_end'), 0);")

        IFS="|" read -r sent junk requests bytes <<< "$stats"

        printf "  Week %d (%s):  %6d     %5d   %9d     %s\n" \
            "$week_num" "${week_start:5}" "$sent" "$junk" "$requests" "$(human_bytes $bytes)"

        week_start=$(date -d "$week_start +7 days" +%Y-%m-%d)
        ((week_num++))
    done

    echo ""
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    generate_monthly_report "$1"
fi
