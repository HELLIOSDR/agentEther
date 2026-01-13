#!/bin/bash
# Notification system for coordination events

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE")
NOTIFICATIONS_ENABLED=$(jq -r '.notifications.enabled // true' "$CONFIG_FILE")

# Check if notifications are enabled
if [ "$NOTIFICATIONS_ENABLED" != "true" ]; then
    exit 0
fi

# Parse arguments
EVENT_TYPE="$1"
EVENT_DATA="$2"

if [ -z "$EVENT_TYPE" ]; then
    echo "Usage: $0 <event_type> [event_data]"
    echo ""
    echo "Event types:"
    echo "  new_message      - New message received"
    echo "  task_assigned    - Task assigned to you"
    echo "  task_completed   - Task you created was completed"
    echo "  environment_active - Another environment became active"
    echo "  sync_failed      - Sync operation failed"
    exit 1
fi

# Notification title and message
TITLE=""
MESSAGE=""
URGENCY="normal"

case "$EVENT_TYPE" in
    new_message)
        TITLE="📬 New Coordination Message"
        MESSAGE="You have a new message in the coordination system"
        URGENCY="normal"
        ;;
    task_assigned)
        TITLE="📋 Task Assigned"
        MESSAGE="A new task has been assigned to $ENV_NAME: $EVENT_DATA"
        URGENCY="normal"
        ;;
    task_completed)
        TITLE="✅ Task Completed"
        MESSAGE="Task completed: $EVENT_DATA"
        URGENCY="low"
        ;;
    environment_active)
        TITLE="🟢 Environment Active"
        MESSAGE="$EVENT_DATA environment is now active"
        URGENCY="low"
        ;;
    sync_failed)
        TITLE="⚠️ Sync Failed"
        MESSAGE="Coordination sync failed: $EVENT_DATA"
        URGENCY="critical"
        ;;
    urgent_message)
        TITLE="🚨 URGENT Message"
        MESSAGE="$EVENT_DATA"
        URGENCY="critical"
        ;;
    *)
        TITLE="ℹ️ Coordination Event"
        MESSAGE="$EVENT_TYPE: $EVENT_DATA"
        URGENCY="normal"
        ;;
esac

# Send notification via available methods

# Method 1: notify-send (Linux desktop)
if command -v notify-send > /dev/null 2>&1; then
    notify-send -u "$URGENCY" "$TITLE" "$MESSAGE"
fi

# Method 2: osascript (macOS)
if command -v osascript > /dev/null 2>&1; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
fi

# Method 3: Terminal bell + echo (fallback)
if [ -t 1 ]; then
    echo -e "\a"  # Bell
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  $TITLE"
    echo "═══════════════════════════════════════════"
    echo "$MESSAGE"
    echo ""
fi

# Method 4: Log to file
LOG_FILE="${SCRIPT_DIR}/../logs/notifications.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] [$EVENT_TYPE] $TITLE: $MESSAGE" >> "$LOG_FILE"

# Method 5: Webhook (optional - if configured)
WEBHOOK_URL=$(jq -r '.notifications.webhookUrl // empty' "$CONFIG_FILE" 2>/dev/null)
if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"urgency\":\"$URGENCY\",\"environment\":\"$ENV_NAME\"}" \
        > /dev/null 2>&1 || true
fi
