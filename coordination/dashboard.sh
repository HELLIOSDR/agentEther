#!/bin/bash
# Display coordination dashboard

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${SCRIPT_DIR}/state.json"
TASKS_FILE="${SCRIPT_DIR}/tasks.json"
MESSAGES_DIR="${SCRIPT_DIR}/messages"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "❌ State file not found"
    exit 1
fi

ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

# Function to calculate time ago
time_ago() {
    local timestamp="$1"
    if [ -z "$timestamp" ] || [ "$timestamp" = "null" ]; then
        echo "never"
        return
    fi

    local now=$(date -u +%s)
    local then=$(date -u -d "$timestamp" +%s 2>/dev/null || echo "$now")
    local diff=$((now - then))

    if [ $diff -lt 60 ]; then
        echo "${diff}s ago"
    elif [ $diff -lt 3600 ]; then
        echo "$((diff / 60))m ago"
    elif [ $diff -lt 86400 ]; then
        echo "$((diff / 3600))h ago"
    else
        echo "$((diff / 86400))d ago"
    fi
}

# Get environment statuses
SWISSAI_STATUS=$(jq -r '.environments.swissai.status' "$STATE_FILE")
SWISSAI_LAST_SEEN=$(jq -r '.environments.swissai.lastSeen' "$STATE_FILE")
SWISSAI_TASK=$(jq -r '.environments.swissai.currentTask // "-"' "$STATE_FILE")

ANTHROPIC_STATUS=$(jq -r '.environments.anthropic.status' "$STATE_FILE")
ANTHROPIC_LAST_SEEN=$(jq -r '.environments.anthropic.lastSeen' "$STATE_FILE")
ANTHROPIC_TASK=$(jq -r '.environments.anthropic.currentTask // "-"' "$STATE_FILE")

# Count messages and tasks
UNREAD_COUNT=0
if [ -d "$MESSAGES_DIR" ]; then
    UNREAD_COUNT=$(find "$MESSAGES_DIR" -name "*.json" -exec jq -r "select(.to == \"$ENV_NAME\" or .to == \"all\") | select(.status == \"unread\") | .id" {} \; 2>/dev/null | wc -l)
fi

ACTIVE_TASKS=0
if [ -f "$TASKS_FILE" ]; then
    ACTIVE_TASKS=$(jq '[.tasks[] | select(.status != "completed")] | length' "$TASKS_FILE")
fi

# Get last sync time
LAST_SYNC=$(jq -r '.statistics.lastSync' "$STATE_FILE")
LAST_SYNC_AGO=$(time_ago "$LAST_SYNC")

# Draw dashboard
# Only clear if TERM is set
[ -n "$TERM" ] && command -v clear >/dev/null && clear
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Claude Coordination Protocol - Dashboard                  ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Environment       │ Status  │ Last Seen    │ Current Task   ║"
echo "║────────────────────┼─────────┼──────────────┼────────────────║"

# SWISSAI row
printf "║  %-17s │ " "swissai"
if [ "$SWISSAI_STATUS" = "active" ]; then
    printf "🟢 %-6s│ " "active"
else
    printf "⚪ %-6s│ " "$SWISSAI_STATUS"
fi
printf "%-13s│ " "$(time_ago "$SWISSAI_LAST_SEEN")"
printf "%-15s║\n" "${SWISSAI_TASK:0:15}"

# Anthropic row
printf "║  %-17s │ " "anthropic"
if [ "$ANTHROPIC_STATUS" = "active" ]; then
    printf "🟢 %-6s│ " "active"
else
    printf "⚪ %-6s│ " "$ANTHROPIC_STATUS"
fi
printf "%-13s│ " "$(time_ago "$ANTHROPIC_LAST_SEEN")"
printf "%-15s║\n" "${ANTHROPIC_TASK:0:15}"

echo "╠═══════════════════════════════════════════════════════════════╣"

# Statistics
printf "║  Active Tasks: %-3d                                           ║\n" "$ACTIVE_TASKS"
printf "║  Unread Messages: %-3d                                        ║\n" "$UNREAD_COUNT"
printf "║  Last Sync: %-50s║\n" "$LAST_SYNC_AGO"

echo "╠═══════════════════════════════════════════════════════════════╣"

# Current environment indicator
printf "║  Current Environment: %-40s║\n" "$ENV_NAME"

echo "╚═══════════════════════════════════════════════════════════════╝"

# Show active issues
ISSUE_COUNT=$(jq '[.activeIssues[] | select(.status != "closed")] | length' "$STATE_FILE")
if [ "$ISSUE_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠️  Active Issues:"
    jq -r '.activeIssues[] | select(.status != "closed") |
        "  • [\(.priority | ascii_upcase)] \(.title)\n    Assigned: \(.assignedTo // "unassigned") | Status: \(.status)"' \
        "$STATE_FILE"
fi

echo ""
echo "Commands:"
echo "  ./coordination/sync-all.sh       - Sync and check updates"
echo "  ./coordination/read-messages.sh  - Read messages"
echo "  ./coordination/check-tasks.sh    - Check tasks"
echo "  ./coordination/send-message.sh   - Send message"
echo ""
