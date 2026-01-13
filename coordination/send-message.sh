#!/bin/bash
# Send message to another environment

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
TO=""
SUBJECT=""
BODY=""
PRIORITY="normal"
REPLY_TO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --to)
            TO="$2"
            shift 2
            ;;
        --subject)
            SUBJECT="$2"
            shift 2
            ;;
        --body)
            BODY="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --reply-to)
            REPLY_TO="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TO" ] || [ -z "$SUBJECT" ] || [ -z "$BODY" ]; then
    echo "Usage: $0 --to <environment> --subject <subject> --body <body> [--priority <normal|high|urgent>] [--reply-to <msg-id>]"
    echo ""
    echo "Examples:"
    echo "  $0 --to anthropic --subject 'Need help' --body 'Can you check the logs?'"
    echo "  $0 --to swissai --subject 'Done' --body 'Tests passed' --priority high"
    echo "  $0 --to all --subject 'Update' --body 'Docker compose updated'"
    exit 1
fi

# Generate message ID
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MSG_ID="msg-$(date +%s)-$(openssl rand -hex 4 2>/dev/null || echo $RANDOM)"
MSG_FILE="${MESSAGES_DIR}/${MSG_ID}.json"

# Create message
jq -n \
    --arg id "$MSG_ID" \
    --arg from "$ENV_NAME" \
    --arg to "$TO" \
    --arg timestamp "$TIMESTAMP" \
    --arg subject "$SUBJECT" \
    --arg body "$BODY" \
    --arg priority "$PRIORITY" \
    --arg replyTo "$REPLY_TO" \
    '{
        id: $id,
        from: $from,
        to: $to,
        timestamp: $timestamp,
        type: "message",
        subject: $subject,
        body: $body,
        priority: $priority,
        replyTo: ($replyTo | if . == "" then null else . end),
        status: "unread",
        attachments: []
    }' > "$MSG_FILE"

echo "✅ Message sent: $MSG_ID"
echo "   From: $ENV_NAME"
echo "   To: $TO"
echo "   Subject: $SUBJECT"
echo "   Priority: $PRIORITY"
echo ""
echo "💡 Don't forget to sync to Google Drive:"
echo "   ./sync-gdrive.sh"
