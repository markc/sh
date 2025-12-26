#!/bin/bash
# Stats - Unified Usage Reporting CLI

set -e

STATS_LIB="${STATS_LIB:-$HOME/.rc/stats.d}"
source "$STATS_LIB/lib/common.sh"

VERSION="1.1.0"

usage() {
    cat << EOF
Stats v$VERSION - Unified Server Usage Reporting

Usage: stats <command> [options]

Commands:
  collect [collectors...]    Run data collectors (default: all)
                            Available: mail, spam, web, network, system
  report [type]             Generate report (default: daily)
                            Types: daily, weekly, monthly
  query <type>              Query stored data
                            Types: spam, web, mail, network, system
  init                      Initialize/reset database
  prune [days]              Remove data older than N days (default: 365)
  help                      Show this help

Options:
  --date=YYYY-MM-DD         Date for daily/weekly reports (default: yesterday)
  --month=YYYY-MM           Month for monthly reports (default: last month)
  --email                   Send report via email
  --debug                   Enable debug logging

Examples:
  stats collect                    # Collect all stats for yesterday
  stats collect mail spam          # Collect only mail and spam
  stats collect --date=2025-12-25  # Collect for specific date
  stats report                     # Daily report to stdout
  stats report --email             # Email daily report
  stats report weekly              # Weekly report (last 7 days)
  stats report weekly --email      # Email weekly report
  stats report monthly             # Monthly report (last month)
  stats report monthly --month=2025-11  # Specific month
  stats query spam                 # Show recent spam stats
  stats prune 90                   # Keep only 90 days
EOF
}

cmd_collect() {
    local collectors=("$@")
    local ymd="$DATE"

    # Default to all collectors if none specified
    if [ ${#collectors[@]} -eq 0 ]; then
        collectors=(mail spam web network system)
    fi

    log_info "Starting collection for $ymd: ${collectors[*]}"

    for collector in "${collectors[@]}"; do
        local script="$STATS_LIB/collectors/${collector}.sh"
        if [ -f "$script" ]; then
            echo "Collecting $collector..."
            source "$script"
            "collect_${collector}" "$ymd"
        else
            echo "Unknown collector: $collector"
        fi
    done

    log_info "Collection complete"
}

cmd_report() {
    local type="${1:-daily}"
    local report=""
    local subject=""

    case "$type" in
        daily)
            source "$STATS_LIB/reports/daily.sh"
            report=$(generate_daily_report "$DATE")
            subject="Daily Server Stats - $HOSTNAME - $DATE"
            ;;
        weekly)
            source "$STATS_LIB/reports/weekly.sh"
            report=$(generate_weekly_report "$DATE")
            local week_start=$(date -d "$DATE -6 days" +%Y-%m-%d)
            subject="Weekly Server Stats - $HOSTNAME - $week_start to $DATE"
            ;;
        monthly)
            source "$STATS_LIB/reports/monthly.sh"
            report=$(generate_monthly_report "$MONTH")
            local month_name=$(date -d "${MONTH}-01" +"%B %Y")
            subject="Monthly Server Stats - $HOSTNAME - $month_name"
            ;;
        *)
            echo "Unknown report type: $type"
            return 1
            ;;
    esac

    if [ "$SEND_EMAIL" = "1" ]; then
        echo "$report" | mail -s "$subject" "$REPORT_EMAIL"
        echo "Report sent to $REPORT_EMAIL"
    else
        echo "$report"
    fi
}

cmd_query() {
    local type="${1:-spam}"

    case "$type" in
        spam)
            echo "=== Recent Spam Stats (last 7 days) ==="
            printf "%-12s %6s %6s %6s %6s %6s\n" "Date" "Inbox" "Junk" "Trash" "Good" "Spam"
            echo "------------------------------------------------------------"
            db_query "SELECT ymd, SUM(inbox_count), SUM(junk_count), SUM(trash_count),
                      SUM(train_good), SUM(train_spam)
                      FROM daily_spam GROUP BY ymd ORDER BY ymd DESC LIMIT 7;" | \
            while IFS="|" read -r ymd inbox junk trash good spam; do
                printf "%-12s %6d %6d %6d %6d %6d\n" "$ymd" "$inbox" "$junk" "$trash" "$good" "$spam"
            done
            ;;
        web)
            echo "=== Recent Web Stats (last 7 days) ==="
            printf "%-12s %10s %12s %8s\n" "Date" "Requests" "Bandwidth" "Errors"
            echo "------------------------------------------------------------"
            db_query "SELECT ymd, SUM(requests), SUM(bytes_sent), SUM(status_5xx)
                      FROM daily_web GROUP BY ymd ORDER BY ymd DESC LIMIT 7;" | \
            while IFS="|" read -r ymd requests bytes errors; do
                printf "%-12s %10d %12s %8d\n" "$ymd" "$requests" "$(human_bytes $bytes)" "$errors"
            done
            ;;
        mail)
            echo "=== Recent Mail Stats (last 7 days) ==="
            printf "%-12s %6s %6s %6s %8s\n" "Date" "Sent" "Bounce" "Reject" "AuthFail"
            echo "------------------------------------------------------------"
            db_query "SELECT ymd, sent, bounced, rejected, auth_failures
                      FROM daily_mail ORDER BY ymd DESC LIMIT 7;" | \
            while IFS="|" read -r ymd sent bounced rejected auth; do
                printf "%-12s %6d %6d %6d %8d\n" "$ymd" "$sent" "$bounced" "$rejected" "$auth"
            done
            ;;
        network)
            echo "=== Recent Network Stats (last 7 days) ==="
            printf "%-12s %10s %12s %12s\n" "Date" "Interface" "Download" "Upload"
            echo "------------------------------------------------------------"
            db_query "SELECT ymd, interface, rx_bytes, tx_bytes
                      FROM daily_network ORDER BY ymd DESC LIMIT 14;" | \
            while IFS="|" read -r ymd iface rx tx; do
                printf "%-12s %10s %12s %12s\n" "$ymd" "$iface" "$(human_bytes $rx)" "$(human_bytes $tx)"
            done
            ;;
        system)
            echo "=== Recent System Stats (last 7 days) ==="
            printf "%-12s %8s %10s %6s %8s\n" "Date" "Disk%" "Memory MB" "Load" "Uptime"
            echo "------------------------------------------------------------"
            db_query "SELECT ymd, disk_pct, mem_used_mb, load_1m, uptime_days
                      FROM daily_system ORDER BY ymd DESC LIMIT 7;" | \
            while IFS="|" read -r ymd disk mem load uptime; do
                printf "%-12s %8s %10d %6s %8dd\n" "$ymd" "${disk}%" "$mem" "$load" "$uptime"
            done
            ;;
        *)
            echo "Unknown query type: $type"
            return 1
            ;;
    esac
}

cmd_init() {
    echo "Initializing database..."
    db_query "SELECT COUNT(*) FROM daily_mail;" >/dev/null 2>&1 || {
        echo "Database initialization failed"
        return 1
    }
    echo "Database ready at $STATS_DB"
}

cmd_prune() {
    local days="${1:-365}"
    echo "Pruning data older than $days days..."
    db_prune "$days"
}

# Parse arguments
DATE=$(yesterday)
MONTH=$(date -d "last month" +%Y-%m)
SEND_EMAIL=0
DEBUG=0
COMMAND=""
ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --date=*)
            DATE="${1#*=}"
            ;;
        --month=*)
            MONTH="${1#*=}"
            ;;
        --email)
            SEND_EMAIL=1
            ;;
        --debug)
            DEBUG=1
            export DEBUG
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                COMMAND="$1"
            else
                ARGS+=("$1")
            fi
            ;;
    esac
    shift
done

# Default command
[ -z "$COMMAND" ] && COMMAND="collect"

# Execute command
case "$COMMAND" in
    collect)
        cmd_collect "${ARGS[@]}"
        ;;
    report)
        cmd_report "${ARGS[@]}"
        ;;
    query)
        cmd_query "${ARGS[@]}"
        ;;
    init)
        cmd_init
        ;;
    prune)
        cmd_prune "${ARGS[@]}"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
