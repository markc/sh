#!/bin/bash
# ServerStats - Mail Collector
# Parses Postfix mail.log for delivery statistics
# /usr/local/lib/serverstats/collectors/mail.sh

source /usr/local/lib/serverstats/lib/common.sh

collect_mail() {
    local ymd="${1:-$(yesterday)}"

    log_info "Collecting mail stats for $ymd"

    if [ ! -f "$MAIL_LOG" ]; then
        log_error "Mail log not found: $MAIL_LOG"
        return 1
    fi

    # Filter log entries for the target date (ISO format: 2025-12-26T)
    local daylog=$(grep "^${ymd}T" "$MAIL_LOG")

    if [ -z "$daylog" ]; then
        log_info "No mail log entries for $ymd"
        db_upsert_mail "$ymd" 0 0 0 0 0 0 "[]" "[]" "[]"
        return 0
    fi

    # Count delivery statuses
    local sent=$(echo "$daylog" | grep -c "status=sent" || echo 0)
    local bounced=$(echo "$daylog" | grep -c "status=bounced" || echo 0)
    local deferred=$(echo "$daylog" | grep -c "status=deferred" || echo 0)
    local rejected=$(echo "$daylog" | grep -c "reject:" || echo 0)
    local connections=$(echo "$daylog" | grep -c "connect from" || echo 0)
    local auth_failures=$(echo "$daylog" | grep -c "authentication failed" || echo 0)

    # Top senders (JSON array)
    local top_senders=$(echo "$daylog" | grep "from=<" | \
        grep -oE "from=<[^>]+>" | sed 's/from=<//;s/>//' | \
        sort | uniq -c | sort -rn | head -5 | \
        awk '{print "{\"addr\":\"" $2 "\",\"count\":" $1 "}"}' | \
        paste -sd "," | sed 's/^/[/;s/$/]/')

    # Top recipients (JSON array)
    local top_recipients=$(echo "$daylog" | grep "status=sent" | \
        grep -oE "to=<[^>]+>" | sed 's/to=<//;s/>//' | \
        sort | uniq -c | sort -rn | head -5 | \
        awk '{print "{\"addr\":\"" $2 "\",\"count\":" $1 "}"}' | \
        paste -sd "," | sed 's/^/[/;s/$/]/')

    # Top rejected IPs (JSON array)
    local top_rejected="[]"
    if [ "$auth_failures" -gt 0 ]; then
        top_rejected=$(echo "$daylog" | grep "authentication failed" | \
            grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
            sort | uniq -c | sort -rn | head -5 | \
            awk '{print "{\"ip\":\"" $2 "\",\"count\":" $1 "}"}' | \
            paste -sd "," | sed 's/^/[/;s/$/]/')
    fi

    # Handle empty JSON
    [ -z "$top_senders" ] && top_senders="[]"
    [ -z "$top_recipients" ] && top_recipients="[]"
    [ -z "$top_rejected" ] && top_rejected="[]"

    # Store in database
    db_upsert_mail "$ymd" "$sent" "$bounced" "$deferred" "$rejected" "$connections" "$auth_failures" "$top_senders" "$top_recipients" "$top_rejected"

    log_info "Mail stats: sent=$sent bounced=$bounced deferred=$deferred rejected=$rejected auth_fail=$auth_failures"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    collect_mail "$1"
fi
