#!/bin/bash
# Create a new task in coordination system

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
TITLE=""
DESCRIPTION=""
PRIORITY=2
ASSIGNED_TO=""
BRANCH=""
TAGS=""
DEPENDENCIES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --title)
            TITLE="$2"
            shift 2
            ;;
        --description|--desc)
            DESCRIPTION="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --assign)
            ASSIGNED_TO="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --depends-on)
            DEPENDENCIES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TITLE" ]; then
    echo "Usage: $0 --title <title> [options]"
    echo ""
    echo "Required:"
    echo "  --title <text>        - Task title"
    echo ""
    echo "Optional:"
    echo "  --description <text>  - Task description"
    echo "  --priority <1-5>      - Priority (1=highest, 5=lowest, default=2)"
    echo "  --assign <env>        - Assign to environment (swissai, anthropic, or leave empty)"
    echo "  --branch <name>       - Git branch for this task"
    echo "  --tags <tag1,tag2>    - Comma-separated tags"
    echo "  --depends-on <id>     - Task ID this depends on"
    echo ""
    echo "Examples:"
    echo "  $0 --title 'Implement feature X' --priority 1 --assign anthropic"
    echo "  $0 --title 'Fix bug Y' --desc 'Issue #123' --tags 'bug,urgent'"
    exit 1
fi

# Generate task ID
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TASK_ID="task-$(date +%s)-$(openssl rand -hex 3 2>/dev/null || echo $RANDOM)"

# Parse tags into array
if [ -n "$TAGS" ]; then
    TAGS_JSON=$(echo "$TAGS" | jq -R 'split(",")')
else
    TAGS_JSON="[]"
fi

# Parse dependencies into array
if [ -n "$DEPENDENCIES" ]; then
    DEPS_JSON=$(echo "$DEPENDENCIES" | jq -R 'split(",")')
else
    DEPS_JSON="[]"
fi

# Create task object
TASK=$(jq -n \
    --arg id "$TASK_ID" \
    --arg title "$TITLE" \
    --arg desc "$DESCRIPTION" \
    --argjson priority "$PRIORITY" \
    --arg assignedTo "$ASSIGNED_TO" \
    --arg createdBy "$ENV_NAME" \
    --arg createdAt "$TIMESTAMP" \
    --arg branch "$BRANCH" \
    --argjson tags "$TAGS_JSON" \
    --argjson deps "$DEPS_JSON" \
    '{
        id: $id,
        title: $title,
        description: $desc,
        priority: $priority,
        status: "pending",
        assignedTo: (if $assignedTo == "" then null else $assignedTo end),
        createdBy: $createdBy,
        createdAt: $createdAt,
        updatedAt: $createdAt,
        startedAt: null,
        completedAt: null,
        branch: (if $branch == "" then null else $branch end),
        tags: $tags,
        dependencies: $deps,
        comments: [],
        estimatedHours: null,
        actualHours: null
    }')

# Add task to tasks.json
TMP_FILE=$(mktemp)

if [ ! -f "$TASKS_FILE" ]; then
    echo '{"version": "1.0.0", "tasks": []}' > "$TASKS_FILE"
fi

jq --argjson task "$TASK" '.tasks += [$task]' "$TASKS_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$TASKS_FILE"

# Display created task
echo "✅ Task created: $TASK_ID"
echo ""
echo "  Title: $TITLE"
[ -n "$DESCRIPTION" ] && echo "  Description: $DESCRIPTION"
echo "  Priority: $PRIORITY"
echo "  Status: pending"
[ -n "$ASSIGNED_TO" ] && echo "  Assigned to: $ASSIGNED_TO" || echo "  Assigned to: unassigned"
echo "  Created by: $ENV_NAME"
echo "  Created at: $TIMESTAMP"
[ -n "$BRANCH" ] && echo "  Branch: $BRANCH"
[ -n "$TAGS" ] && echo "  Tags: $TAGS"
[ -n "$DEPENDENCIES" ] && echo "  Depends on: $DEPENDENCIES"
echo ""
echo "💡 Don't forget to sync:"
echo "   ./sync-gdrive.sh"
echo ""
echo "📝 To assign this task:"
echo "   ./coordination/assign-task.sh --task $TASK_ID --to <environment>"
