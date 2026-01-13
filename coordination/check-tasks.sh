#!/bin/bash
# Check for tasks assigned to current environment

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

# Check if tasks file exists
if [ ! -f "$TASKS_FILE" ]; then
    echo "📋 No tasks file found"
    exit 0
fi

# Get tasks assigned to this environment or unassigned
ASSIGNED_TASKS=$(jq -r \
    --arg env "$ENV_NAME" \
    '.tasks[] | select(.assignedTo == $env or .assignedTo == null) |
    "\(.id)|\(.priority)|\(.title)|\(.status)|\(.assignedTo // "unassigned")"' \
    "$TASKS_FILE")

if [ -z "$ASSIGNED_TASKS" ]; then
    echo "✅ No tasks assigned to ${ENV_NAME}"
    exit 0
fi

echo "📋 Tasks for ${ENV_NAME}:"
echo ""
echo "ID          | Pri | Status      | Title"
echo "----------- | --- | ----------- | ----------------------------------------"

echo "$ASSIGNED_TASKS" | while IFS='|' read -r id priority title status assigned; do
    printf "%-11s | %-3s | %-11s | %s\n" "$id" "$priority" "$status" "$title"
done

echo ""
echo "To accept a task, run: ./coordination/accept-task.sh <task-id>"
