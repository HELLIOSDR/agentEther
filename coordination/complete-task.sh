#!/bin/bash
# Mark a task as completed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKS_FILE="${SCRIPT_DIR}/tasks.json"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE")

# Parse arguments
TASK_ID="$1"
COMMENT=""

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 <task-id> [comment]"
    echo ""
    echo "Example:"
    echo "  $0 task-123"
    echo "  $0 task-123 'Fixed bug by updating config'"
    exit 1
fi

shift
COMMENT="$*"

# Check if task exists
if ! jq -e ".tasks[] | select(.id == \"$TASK_ID\")" "$TASKS_FILE" > /dev/null 2>&1; then
    echo "❌ Task not found: $TASK_ID"
    exit 1
fi

# Update task to completed
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP_FILE=$(mktemp)

if [ -n "$COMMENT" ]; then
    # Add completion comment
    jq \
        --arg taskId "$TASK_ID" \
        --arg timestamp "$TIMESTAMP" \
        --arg env "$ENV_NAME" \
        --arg comment "$COMMENT" \
        '(.tasks[] | select(.id == $taskId)) |= (
            .status = "completed" |
            .completedAt = $timestamp |
            .updatedAt = $timestamp |
            .comments += [{
                author: $env,
                timestamp: $timestamp,
                text: $comment,
                type: "completion"
            }]
        )' "$TASKS_FILE" > "$TMP_FILE"
else
    jq \
        --arg taskId "$TASK_ID" \
        --arg timestamp "$TIMESTAMP" \
        '(.tasks[] | select(.id == $taskId)) |= (
            .status = "completed" |
            .completedAt = $timestamp |
            .updatedAt = $timestamp
        )' "$TASKS_FILE" > "$TMP_FILE"
fi

mv "$TMP_FILE" "$TASKS_FILE"

# Get task details
TASK_TITLE=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .title" "$TASKS_FILE")
STARTED_AT=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .startedAt" "$TASKS_FILE")
CREATED_BY=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .createdBy" "$TASKS_FILE")

# Calculate duration if started time exists
DURATION=""
if [ "$STARTED_AT" != "null" ] && [ -n "$STARTED_AT" ]; then
    START_EPOCH=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo 0)
    END_EPOCH=$(date -d "$TIMESTAMP" +%s 2>/dev/null || echo 0)
    DIFF=$((END_EPOCH - START_EPOCH))

    if [ $DIFF -gt 0 ]; then
        HOURS=$((DIFF / 3600))
        MINUTES=$(( (DIFF % 3600) / 60 ))
        if [ $HOURS -gt 0 ]; then
            DURATION="${HOURS}h ${MINUTES}m"
        else
            DURATION="${MINUTES}m"
        fi
    fi
fi

# Update coordination state to idle
"${SCRIPT_DIR}/update-state.sh" --status active --task ""

echo "✅ Task completed!"
echo ""
echo "  Task: $TASK_ID"
echo "  Title: $TASK_TITLE"
echo "  Completed at: $TIMESTAMP"
[ -n "$DURATION" ] && echo "  Duration: $DURATION"
[ -n "$COMMENT" ] && echo "  Comment: $COMMENT"
echo ""
echo "🎉 Great work!"
echo ""
echo "💡 Notify the task creator:"
echo "   ./coordination/send-message.sh --to $CREATED_BY --subject 'Task completed: $TASK_TITLE' --body 'Completed by $ENV_NAME. $COMMENT'"
echo ""
echo "💡 Sync your completion:"
echo "   ./sync-gdrive.sh"
