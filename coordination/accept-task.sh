#!/bin/bash
# Accept a task and mark it as in-progress

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

if [ -z "$TASK_ID" ]; then
    echo "Usage: $0 <task-id>"
    echo ""
    echo "Example:"
    echo "  $0 task-123"
    echo ""
    echo "To see available tasks:"
    echo "  ./coordination/check-tasks.sh"
    exit 1
fi

# Check if task exists
if ! jq -e ".tasks[] | select(.id == \"$TASK_ID\")" "$TASKS_FILE" > /dev/null 2>&1; then
    echo "❌ Task not found: $TASK_ID"
    exit 1
fi

# Check if task is assigned to this environment
ASSIGNED_TO=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .assignedTo" "$TASKS_FILE")

if [ "$ASSIGNED_TO" != "$ENV_NAME" ] && [ "$ASSIGNED_TO" != "null" ]; then
    echo "❌ Task is assigned to $ASSIGNED_TO, not $ENV_NAME"
    echo "💡 To assign to yourself, run:"
    echo "   ./coordination/assign-task.sh --task $TASK_ID --to $ENV_NAME"
    exit 1
fi

# Update task to in-progress
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP_FILE=$(mktemp)

jq \
    --arg taskId "$TASK_ID" \
    --arg env "$ENV_NAME" \
    --arg timestamp "$TIMESTAMP" \
    '(.tasks[] | select(.id == $taskId)) |= (
        .status = "in_progress" |
        .assignedTo = $env |
        .startedAt = $timestamp |
        .updatedAt = $timestamp
    )' "$TASKS_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$TASKS_FILE"

# Get task details
TASK_TITLE=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .title" "$TASKS_FILE")
TASK_DESC=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .description" "$TASKS_FILE")
TASK_PRIORITY=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .priority" "$TASKS_FILE")

# Update coordination state
"${SCRIPT_DIR}/update-state.sh" --status active --task "$TASK_ID"

echo "✅ Task accepted and started"
echo ""
echo "  Task: $TASK_ID"
echo "  Title: $TASK_TITLE"
[ "$TASK_DESC" != "null" ] && [ -n "$TASK_DESC" ] && echo "  Description: $TASK_DESC"
echo "  Priority: $TASK_PRIORITY"
echo "  Status: in_progress"
echo "  Started at: $TIMESTAMP"
echo ""
echo "💡 When done, mark as complete:"
echo "   ./coordination/complete-task.sh $TASK_ID"
echo ""
echo "💡 Sync your progress:"
echo "   ./sync-gdrive.sh"
