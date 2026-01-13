#!/bin/bash
# Sync coordination state with Google Drive and update heartbeat

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔄 Syncing coordination state..."
echo ""

# Update heartbeat
echo "💓 Sending heartbeat..."
"${SCRIPT_DIR}/update-state.sh" --heartbeat

# Sync to Google Drive
echo ""
echo "☁️  Syncing to Google Drive..."
"${PROJECT_DIR}/sync-gdrive.sh"

echo ""
echo "✅ Coordination sync complete!"
echo ""

# Check for new messages
echo "📬 Checking for new messages..."
"${SCRIPT_DIR}/read-messages.sh" --unread

echo ""

# Check for tasks
echo "📋 Checking for tasks..."
"${SCRIPT_DIR}/check-tasks.sh"
