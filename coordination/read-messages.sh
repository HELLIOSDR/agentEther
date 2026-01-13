#!/bin/bash
# Read messages for current environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESSAGES_DIR="${SCRIPT_DIR}/messages"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE")

# Parse arguments
UNREAD_ONLY=false
MARK_READ=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unread)
            UNREAD_ONLY=true
            shift
            ;;
        --mark-read)
            MARK_READ=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if messages directory exists
if [ ! -d "$MESSAGES_DIR" ]; then
    echo "📭 No messages directory found"
    exit 0
fi

# Find messages for this environment
MESSAGE_COUNT=0
UNREAD_COUNT=0

echo "📬 Messages for ${ENV_NAME}:"
echo ""

for msg_file in "$MESSAGES_DIR"/*.json; do
    [ -f "$msg_file" ] || continue

    TO=$(jq -r '.to' "$msg_file")
    STATUS=$(jq -r '.status' "$msg_file")

    # Check if message is for this environment or "all"
    if [ "$TO" != "$ENV_NAME" ] && [ "$TO" != "all" ]; then
        continue
    fi

    # Check if we should show only unread
    if [ "$UNREAD_ONLY" = true ] && [ "$STATUS" != "unread" ]; then
        continue
    fi

    MESSAGE_COUNT=$((MESSAGE_COUNT + 1))
    [ "$STATUS" = "unread" ] && UNREAD_COUNT=$((UNREAD_COUNT + 1))

    # Extract message details
    MSG_ID=$(jq -r '.id' "$msg_file")
    FROM=$(jq -r '.from' "$msg_file")
    SUBJECT=$(jq -r '.subject' "$msg_file")
    BODY=$(jq -r '.body' "$msg_file")
    PRIORITY=$(jq -r '.priority' "$msg_file")
    TIMESTAMP=$(jq -r '.timestamp' "$msg_file")

    # Format status indicator
    STATUS_ICON="✉️"
    [ "$STATUS" = "unread" ] && STATUS_ICON="📩"
    [ "$PRIORITY" = "high" ] && STATUS_ICON="⚠️"
    [ "$PRIORITY" = "urgent" ] && STATUS_ICON="🚨"

    echo "─────────────────────────────────────────────────────────"
    echo "$STATUS_ICON [$MSG_ID] $STATUS"
    echo "From: $FROM"
    echo "Priority: $PRIORITY"
    echo "Time: $TIMESTAMP"
    echo "Subject: $SUBJECT"
    echo ""
    echo "$BODY"
    echo ""

    # Mark as read if requested
    if [ "$MARK_READ" = true ] && [ "$STATUS" = "unread" ]; then
        TMP_FILE=$(mktemp)
        jq '.status = "read"' "$msg_file" > "$TMP_FILE"
        mv "$TMP_FILE" "$msg_file"
        echo "✓ Marked as read"
        echo ""
    fi
done

echo "─────────────────────────────────────────────────────────"

if [ $MESSAGE_COUNT -eq 0 ]; then
    if [ "$UNREAD_ONLY" = true ]; then
        echo "✅ No unread messages"
    else
        echo "📭 No messages"
    fi
else
    echo "Total: $MESSAGE_COUNT message(s)"
    [ $UNREAD_COUNT -gt 0 ] && echo "Unread: $UNREAD_COUNT"
fi

echo ""
echo "💡 To mark all as read: $0 --mark-read"
