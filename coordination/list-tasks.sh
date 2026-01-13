#!/bin/bash
# List tasks with filtering options

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
FILTER_STATUS=""
FILTER_ASSIGNED=""
FILTER_PRIORITY=""
SHOW_COMPLETED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --status)
            FILTER_STATUS="$2"
            shift 2
            ;;
        --assigned-to)
            FILTER_ASSIGNED="$2"
            shift 2
            ;;
        --priority)
            FILTER_PRIORITY="$2"
            shift 2
            ;;
        --all)
            SHOW_COMPLETED=true
            shift
            ;;
        --mine)
            FILTER_ASSIGNED="$ENV_NAME"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --status <status>       Filter by status (pending, in_progress, completed)"
            echo "  --assigned-to <env>     Filter by assigned environment"
            echo "  --priority <1-5>        Filter by priority"
            echo "  --mine                  Show only tasks assigned to me"
            echo "  --all                   Show all tasks including completed"
            echo ""
            echo "Examples:"
            echo "  $0                           # Show pending and in_progress tasks"
            echo "  $0 --mine                    # Show my tasks"
            echo "  $0 --status pending          # Show only pending tasks"
            echo "  $0 --priority 1 --mine       # Show my high-priority tasks"
            echo "  $0 --all                     # Show all tasks"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if tasks file exists
if [ ! -f "$TASKS_FILE" ]; then
    echo "📋 No tasks file found"
    exit 0
fi

# Build jq filter
JQ_FILTER=".tasks[]"

if [ -n "$FILTER_STATUS" ]; then
    JQ_FILTER="$JQ_FILTER | select(.status == \"$FILTER_STATUS\")"
elif [ "$SHOW_COMPLETED" = false ]; then
    JQ_FILTER="$JQ_FILTER | select(.status != \"completed\")"
fi

if [ -n "$FILTER_ASSIGNED" ]; then
    JQ_FILTER="$JQ_FILTER | select(.assignedTo == \"$FILTER_ASSIGNED\" or (.assignedTo == null and \"$FILTER_ASSIGNED\" == \"unassigned\"))"
fi

if [ -n "$FILTER_PRIORITY" ]; then
    JQ_FILTER="$JQ_FILTER | select(.priority == $FILTER_PRIORITY)"
fi

# Get filtered tasks
TASKS=$(jq -r "$JQ_FILTER | \"\(.id)|\(.priority)|\(.status)|\(.assignedTo // \"unassigned\")|\(.title)|\(.createdBy)|\(.createdAt)\"" "$TASKS_FILE" 2>/dev/null || echo "")

if [ -z "$TASKS" ]; then
    echo "✅ No tasks match the filter"
    exit 0
fi

# Count tasks by status
TOTAL=$(echo "$TASKS" | wc -l)
PENDING=$(echo "$TASKS" | grep "|pending|" | wc -l)
IN_PROGRESS=$(echo "$TASKS" | grep "|in_progress|" | wc -l)
COMPLETED=$(echo "$TASKS" | grep "|completed|" | wc -l)

# Display header
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  Task List - $ENV_NAME Environment"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Summary: $TOTAL total | $PENDING pending | $IN_PROGRESS in progress | $COMPLETED completed"
echo ""
echo "───────────────────────────────────────────────────────────────────────────────"
printf "%-15s │ %-3s │ %-12s │ %-10s │ %-30s\n" "ID" "Pri" "Status" "Assigned" "Title"
echo "───────────────────────────────────────────────────────────────────────────────"

# Display tasks
echo "$TASKS" | while IFS='|' read -r id priority status assigned title created_by created_at; do
    # Truncate long titles
    if [ ${#title} -gt 30 ]; then
        title="${title:0:27}..."
    fi

    # Color status
    case $status in
        pending)
            status_display="⏳ pending"
            ;;
        in_progress)
            status_display="🔄 in_progres"
            ;;
        completed)
            status_display="✅ completed"
            ;;
        *)
            status_display="$status"
            ;;
    esac

    # Highlight if assigned to current environment
    if [ "$assigned" = "$ENV_NAME" ]; then
        assigned="→ $assigned"
    fi

    printf "%-15s │ %-3s │ %-12s │ %-10s │ %-30s\n" \
        "${id:0:15}" \
        "$priority" \
        "${status_display:0:12}" \
        "${assigned:0:10}" \
        "$title"
done

echo "───────────────────────────────────────────────────────────────────────────────"
echo ""
echo "Commands:"
echo "  ./coordination/accept-task.sh <task-id>     - Accept and start a task"
echo "  ./coordination/complete-task.sh <task-id>   - Mark task as completed"
echo "  ./coordination/create-task.sh --title '...' - Create a new task"
echo ""
