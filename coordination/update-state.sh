#!/bin/bash
# Update coordination state for current environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE="${SCRIPT_DIR}/state.json"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Parse arguments
HEARTBEAT=false
STATUS=""
TASK=""
COMMIT=""
BRANCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --heartbeat)
            HEARTBEAT=true
            shift
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --task)
            TASK="$2"
            shift 2
            ;;
        --commit)
            COMMIT="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect git info if not provided
if [ -z "$COMMIT" ] && command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

if [ -z "$BRANCH" ] && command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
fi

# Create backup
cp "$STATE_FILE" "${STATE_FILE}.bak"

# Update state using jq
TMP_FILE=$(mktemp)

jq \
    --arg env "$ENV_NAME" \
    --arg timestamp "$TIMESTAMP" \
    --arg status "$STATUS" \
    --arg task "$TASK" \
    --arg commit "$COMMIT" \
    --arg branch "$BRANCH" \
    '.lastUpdate = $timestamp |
    .environments[$env].lastSeen = $timestamp |
    (if $status != "" then .environments[$env].status = $status else . end) |
    (if $task != "" then .environments[$env].currentTask = $task else . end) |
    (if $commit != "" then .environments[$env].commit = $commit else . end) |
    (if $branch != "" then .environments[$env].branch = $branch else . end) |
    .statistics.lastSync = $timestamp |
    .statistics.syncCount = (.statistics.syncCount + 1)' \
    "$STATE_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$STATE_FILE"

if [ "$HEARTBEAT" = true ]; then
    echo "💓 Heartbeat sent for ${ENV_NAME}"
else
    echo "✅ State updated for ${ENV_NAME}"
    [ -n "$STATUS" ] && echo "   Status: $STATUS"
    [ -n "$TASK" ] && echo "   Task: $TASK"
    [ -n "$COMMIT" ] && echo "   Commit: $COMMIT"
    [ -n "$BRANCH" ] && echo "   Branch: $BRANCH"
fi

echo "   Timestamp: $TIMESTAMP"
