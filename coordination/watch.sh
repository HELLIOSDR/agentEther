#!/bin/bash
# Watch for coordination events and send notifications

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${SCRIPT_DIR}/state.json"
MESSAGES_DIR="${SCRIPT_DIR}/messages"
TASKS_FILE="${SCRIPT_DIR}/tasks.json"

# Store last known state
LAST_MSG_COUNT=0
LAST_TASK_COUNT=0
LAST_UNREAD_COUNT=0

# Initialize counts
if [ -d "$MESSAGES_DIR" ]; then
    LAST_MSG_COUNT=$(find "$MESSAGES_DIR" -name "*.json" -type f | wc -l)
fi

if [ -f "$TASKS_FILE" ]; then
    LAST_TASK_COUNT=$(jq '[.tasks[]] | length' "$TASKS_FILE" 2>/dev/null || echo 0)
fi

echo "👀 Watching for coordination events..."
echo "   Press Ctrl+C to stop"
echo ""

# Watch loop
while true; do
    # Check for new messages
    if [ -d "$MESSAGES_DIR" ]; then
        CURRENT_MSG_COUNT=$(find "$MESSAGES_DIR" -name "*.json" -type f | wc -l)

        if [ "$CURRENT_MSG_COUNT" -gt "$LAST_MSG_COUNT" ]; then
            NEW_MESSAGES=$((CURRENT_MSG_COUNT - LAST_MSG_COUNT))
            echo "📬 $NEW_MESSAGES new message(s) detected"
            "${SCRIPT_DIR}/notify.sh" new_message "$NEW_MESSAGES message(s)"
            LAST_MSG_COUNT=$CURRENT_MSG_COUNT
        fi
    fi

    # Check for new tasks
    if [ -f "$TASKS_FILE" ]; then
        CURRENT_TASK_COUNT=$(jq '[.tasks[]] | length' "$TASKS_FILE" 2>/dev/null || echo 0)

        if [ "$CURRENT_TASK_COUNT" -gt "$LAST_TASK_COUNT" ]; then
            NEW_TASKS=$((CURRENT_TASK_COUNT - LAST_TASK_COUNT))
            echo "📋 $NEW_TASKS new task(s) detected"

            # Check if any are assigned to me
            CONFIG_FILE="${SCRIPT_DIR}/config.json"
            if [ -f "$CONFIG_FILE" ]; then
                ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE")
                MY_TASKS=$(jq -r ".tasks[] | select(.assignedTo == \"$ENV_NAME\") | .id" "$TASKS_FILE" | wc -l)

                if [ "$MY_TASKS" -gt 0 ]; then
                    TASK_TITLE=$(jq -r ".tasks[] | select(.assignedTo == \"$ENV_NAME\") | .title" "$TASKS_FILE" | head -1)
                    "${SCRIPT_DIR}/notify.sh" task_assigned "$TASK_TITLE"
                fi
            fi

            LAST_TASK_COUNT=$CURRENT_TASK_COUNT
        fi
    fi

    # Check environment status changes
    if [ -f "$STATE_FILE" ]; then
        # Check if other environments became active
        for env in swissai anthropic; do
            STATUS=$(jq -r ".environments.$env.status" "$STATE_FILE" 2>/dev/null || echo "unknown")
            if [ "$STATUS" = "active" ]; then
                # Store last known active state
                STATE_FILE_TMP="/tmp/coordination-watch-${env}.state"
                if [ -f "$STATE_FILE_TMP" ]; then
                    LAST_STATUS=$(cat "$STATE_FILE_TMP")
                    if [ "$LAST_STATUS" != "active" ]; then
                        echo "🟢 $env environment is now active"
                        "${SCRIPT_DIR}/notify.sh" environment_active "$env"
                    fi
                fi
                echo "$STATUS" > "$STATE_FILE_TMP"
            fi
        done
    fi

    # Sleep
    sleep 10
done
