#!/bin/bash
# Assign a task to an environment

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
TASK_ID=""
ASSIGN_TO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --task)
            TASK_ID="$2"
            shift 2
            ;;
        --to)
            ASSIGN_TO="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TASK_ID" ] || [ -z "$ASSIGN_TO" ]; then
    echo "Usage: $0 --task <task-id> --to <environment>"
    echo ""
    echo "Example:"
    echo "  $0 --task task-123 --to anthropic"
    echo ""
    echo "Available environments: swissai, anthropic"
    exit 1
fi

# Check if task exists
if ! jq -e ".tasks[] | select(.id == \"$TASK_ID\")" "$TASKS_FILE" > /dev/null 2>&1; then
    echo "❌ Task not found: $TASK_ID"
    exit 1
fi

# Update task
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP_FILE=$(mktemp)

jq \
    --arg taskId "$TASK_ID" \
    --arg assignTo "$ASSIGN_TO" \
    --arg timestamp "$TIMESTAMP" \
    '(.tasks[] | select(.id == $taskId)) |= (
        .assignedTo = $assignTo |
        .updatedAt = $timestamp
    )' "$TASKS_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$TASKS_FILE"

# Get task details
TASK_TITLE=$(jq -r ".tasks[] | select(.id == \"$TASK_ID\") | .title" "$TASKS_FILE")

echo "✅ Task assigned"
echo ""
echo "  Task: $TASK_ID"
echo "  Title: $TASK_TITLE"
echo "  Assigned to: $ASSIGN_TO"
echo "  Updated at: $TIMESTAMP"
echo ""
echo "💡 Sync and notify:"
echo "   ./sync-gdrive.sh"
echo "   ./coordination/send-message.sh --to $ASSIGN_TO --subject 'New task assigned' --body 'Task: $TASK_TITLE'"
