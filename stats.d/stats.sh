#!/bin/bash
# Stats - Server Usage Reporting
# Wrapper to run from ~/.rc/stats/

STATS_DIR="${HOME}/.rc/stats"
export STATS_LIB="$STATS_DIR"

source "$STATS_DIR/lib/common.sh"
source "$STATS_DIR/main.sh" "$@"
