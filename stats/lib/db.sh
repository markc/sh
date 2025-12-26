#!/bin/bash
# ServerStats - Database helper functions
# /usr/local/lib/serverstats/lib/db.sh

# Escape single quotes for SQLite
sql_escape() {
    echo "${1//\"/\"\"}"
}

# Execute SQL query
db_query() {
    sqlite3 -separator "|" "$STATS_DB" "$1"
}

# Execute SQL and return single value
db_value() {
    sqlite3 "$STATS_DB" "$1"
}

# Insert or update mail stats
db_upsert_mail() {
    local ymd=$1 sent=$2 bounced=$3 deferred=$4 rejected=$5 connections=$6 auth_failures=$7
    local top_senders=$(sql_escape "${8:-[]}")
    local top_recipients=$(sql_escape "${9:-[]}")
    local top_rejected=$(sql_escape "${10:-[]}")
    
    db_query "INSERT INTO daily_mail (ymd, sent, bounced, deferred, rejected, connections, auth_failures, top_senders, top_recipients, top_rejected_ips)
              VALUES (\"$ymd\", $sent, $bounced, $deferred, $rejected, $connections, $auth_failures, \"$top_senders\", \"$top_recipients\", \"$top_rejected\")
              ON CONFLICT(ymd) DO UPDATE SET
                sent=$sent, bounced=$bounced, deferred=$deferred, rejected=$rejected,
                connections=$connections, auth_failures=$auth_failures,
                top_senders=\"$top_senders\", top_recipients=\"$top_recipients\", top_rejected_ips=\"$top_rejected\";"
}

# Insert or update spam stats per mailbox
db_upsert_spam() {
    local ymd=$1 mailbox=$2 inbox=$3 junk=$4 trash=$5 train_good=$6 train_spam=$7
    
    db_query "INSERT INTO daily_spam (ymd, mailbox, inbox_count, junk_count, trash_count, train_good, train_spam)
              VALUES (\"$ymd\", \"$mailbox\", $inbox, $junk, $trash, $train_good, $train_spam)
              ON CONFLICT(ymd, mailbox) DO UPDATE SET
                inbox_count=$inbox, junk_count=$junk, trash_count=$trash,
                train_good=$train_good, train_spam=$train_spam;"
}

# Insert or update web stats per vhost
db_upsert_web() {
    local ymd=$1 vhost=$2 requests=$3 bytes=$4 s2xx=$5 s3xx=$6 s4xx=$7 s5xx=$8 unique_ips=$9
    
    db_query "INSERT INTO daily_web (ymd, vhost, requests, bytes_sent, status_2xx, status_3xx, status_4xx, status_5xx, unique_ips)
              VALUES (\"$ymd\", \"$vhost\", $requests, $bytes, $s2xx, $s3xx, $s4xx, $s5xx, $unique_ips)
              ON CONFLICT(ymd, vhost) DO UPDATE SET
                requests=$requests, bytes_sent=$bytes,
                status_2xx=$s2xx, status_3xx=$s3xx, status_4xx=$s4xx, status_5xx=$s5xx,
                unique_ips=$unique_ips;"
}

# Insert or update network stats per interface
db_upsert_network() {
    local ymd=$1 iface=$2 rx_bytes=$3 tx_bytes=$4 rx_packets=$5 tx_packets=$6
    
    db_query "INSERT INTO daily_network (ymd, interface, rx_bytes, tx_bytes, rx_packets, tx_packets)
              VALUES (\"$ymd\", \"$iface\", $rx_bytes, $tx_bytes, $rx_packets, $tx_packets)
              ON CONFLICT(ymd, interface) DO UPDATE SET
                rx_bytes=$rx_bytes, tx_bytes=$tx_bytes, rx_packets=$rx_packets, tx_packets=$tx_packets;"
}

# Insert or update system stats
db_upsert_system() {
    local ymd=$1 hostname=$2 disk_used=$3 disk_total=$4 disk_pct=$5
    local mem_used=$6 mem_total=$7 swap_used=$8
    local load1=$9 load5=${10} load15=${11} uptime=${12} procs=${13}
    
    db_query "INSERT INTO daily_system (ymd, hostname, disk_used_gb, disk_total_gb, disk_pct, mem_used_mb, mem_total_mb, swap_used_mb, load_1m, load_5m, load_15m, uptime_days, processes)
              VALUES (\"$ymd\", \"$hostname\", $disk_used, $disk_total, $disk_pct, $mem_used, $mem_total, $swap_used, $load1, $load5, $load15, $uptime, $procs)
              ON CONFLICT(ymd) DO UPDATE SET
                hostname=\"$hostname\", disk_used_gb=$disk_used, disk_total_gb=$disk_total, disk_pct=$disk_pct,
                mem_used_mb=$mem_used, mem_total_mb=$mem_total, swap_used_mb=$swap_used,
                load_1m=$load1, load_5m=$load5, load_15m=$load15, uptime_days=$uptime, processes=$procs;"
}

# Get 7-day average for comparison
db_mail_avg() {
    local field=$1
    local ymd=$2
    db_value "SELECT COALESCE(ROUND(AVG($field)), 0) FROM daily_mail WHERE ymd < \"$ymd\" AND ymd >= date(\"$ymd\", \"-7 days\");"
}

db_spam_total() {
    local ymd=$1
    db_query "SELECT COALESCE(SUM(inbox_count),0), COALESCE(SUM(junk_count),0), COALESCE(SUM(trash_count),0), COALESCE(SUM(train_good),0), COALESCE(SUM(train_spam),0) FROM daily_spam WHERE ymd=\"$ymd\";"
}

db_web_total() {
    local ymd=$1
    db_query "SELECT COALESCE(SUM(requests),0), COALESCE(SUM(bytes_sent),0), COALESCE(SUM(status_2xx),0), COALESCE(SUM(status_5xx),0) FROM daily_web WHERE ymd=\"$ymd\";"
}

# Prune old data
db_prune() {
    local days=${1:-365}
    local cutoff=$(date -d "$days days ago" +%Y-%m-%d)
    
    for table in daily_mail daily_spam daily_web daily_network daily_system; do
        local deleted=$(db_value "SELECT COUNT(*) FROM $table WHERE ymd < \"$cutoff\";")
        db_query "DELETE FROM $table WHERE ymd < \"$cutoff\";"
        echo "Pruned $deleted rows from $table"
    done
}
