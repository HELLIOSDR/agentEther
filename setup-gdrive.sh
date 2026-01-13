#!/bin/bash
# Spectrum Protocol 2026 - Google Drive Setup Helper
# Quick setup for rclone with specific Google Drive folder

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GDRIVE_FOLDER_ID="1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo"
REMOTE_NAME="agentether-gdrive"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Spectrum Protocol 2026 - Google Drive Setup  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} rclone not found. Installing..."
    curl https://rclone.org/install.sh | sudo bash
    echo -e "${GREEN}✓${NC} rclone installed"
else
    echo -e "${GREEN}✓${NC} rclone is already installed"
fi

echo ""
echo "Google Drive Folder ID: ${GDRIVE_FOLDER_ID}"
echo "Remote Name: ${REMOTE_NAME}"
echo ""

# Check if remote already exists
if rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
    echo -e "${GREEN}✓${NC} Remote '${REMOTE_NAME}' already configured"
    echo ""
    echo "Test connection:"
    rclone lsd ${REMOTE_NAME}:
    echo ""
    echo -e "${GREEN}✓${NC} Connection successful!"
else
    echo -e "${YELLOW}⚠${NC} Remote '${REMOTE_NAME}' not configured"
    echo ""
    echo "Please run: rclone config"
    echo ""
    echo "Configuration steps:"
    echo "  1. Choose: n (New remote)"
    echo "  2. Name: ${REMOTE_NAME}"
    echo "  3. Type: drive (Google Drive)"
    echo "  4. When asked for root_folder_id: ${GDRIVE_FOLDER_ID}"
    echo "  5. Complete OAuth flow in browser"
    echo ""
    echo "Then run this script again to test the connection."
    exit 1
fi

echo ""
echo "Next steps:"
echo ""
echo "1. Test backup:"
echo "   ./sync-gdrive.sh backup --dry-run"
echo ""
echo "2. Perform first backup:"
echo "   ./sync-gdrive.sh backup"
echo ""
echo "3. Check what's on Google Drive:"
echo "   ./sync-gdrive.sh list"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
