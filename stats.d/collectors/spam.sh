#!/bin/bash
# ServerStats - Spam Collector
# Parses Dovecot sieve debug log for spam filtering statistics
# /usr/local/lib/serverstats/collectors/spam.sh

source /usr/local/lib/serverstats/lib/common.sh

# On this system, sieve debug logs go to mail.log with ISO date format
SPAM_LOG="${SPAM_LOG:-/var/log/mail.log}"

collect_spam() {
    local ymd="${1:-$(yesterday)}"

    log_info "Collecting spam stats for $ymd"

    if [ ! -f "$SPAM_LOG" ]; then
        log_error "Log not found: $SPAM_LOG"
        return 1
    fi

    # Filter log entries for the target date (ISO format: 2025-12-26T)
    local daylog=$(grep "^${ymd}T" "$SPAM_LOG" | grep -E "DELIVERY:|TRAIN:")

    if [ -z "$daylog" ]; then
        log_info "No sieve debug log entries for $ymd"
        return 0
    fi

    # Temporary file for aggregation
    local tmpfile=$(mktemp)

    # Parse DELIVERY entries: "DEBUG: DELIVERY: user@domain -> Inbox|Junk|Trash (score)"
    echo "$daylog" | grep "DELIVERY:" | while read -r line; do
        # Extract: mailbox and destination
        # Format: ... sieve: DEBUG: DELIVERY: user@domain -> Dest (SCORE...)
        local mailbox=$(echo "$line" | sed -n 's/.*DELIVERY: \([^ ]*\) -> .*/\1/p')
        local dest=$(echo "$line" | sed -n 's/.* -> \([^ ]*\) .*/\1/p')

        if [ -n "$mailbox" ] && [ -n "$dest" ]; then
            echo "$mailbox|$dest|delivery" >> "$tmpfile"
        fi
    done

    # Parse TRAIN entries: "DEBUG: TRAIN: user@domain -> good|spam"
    echo "$daylog" | grep "TRAIN:" | while read -r line; do
        local mailbox=$(echo "$line" | sed -n 's/.*TRAIN: \([^ ]*\) -> .*/\1/p')
        local traintype=$(echo "$line" | sed -n 's/.* -> \([^ ]*\).*/\1/p')

        if [ -n "$mailbox" ] && [ -n "$traintype" ]; then
            echo "$mailbox|$traintype|train" >> "$tmpfile"
        fi
    done

    # Aggregate per mailbox
    if [ -s "$tmpfile" ]; then
        # Get unique mailboxes
        cut -d"|" -f1 "$tmpfile" | sort -u | while read -r mailbox; do
            local inbox=$(grep "^${mailbox}|Inbox|delivery$" "$tmpfile" | wc -l)
            local junk=$(grep "^${mailbox}|Junk|delivery$" "$tmpfile" | wc -l)
            local trash=$(grep "^${mailbox}|Trash|delivery$" "$tmpfile" | wc -l)
            local train_good=$(grep "^${mailbox}|good|train$" "$tmpfile" | wc -l)
            local train_spam=$(grep "^${mailbox}|spam|train$" "$tmpfile" | wc -l)

            db_upsert_spam "$ymd" "$mailbox" "$inbox" "$junk" "$trash" "$train_good" "$train_spam"
            log_debug "Spam stats for $mailbox: inbox=$inbox junk=$junk trash=$trash good=$train_good spam=$train_spam"
        done
    fi

    rm -f "$tmpfile"

    # Log summary
    local totals=$(db_spam_total "$ymd")
    log_info "Spam stats totals: $totals"
}

# Run if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    collect_spam "$1"
fi
