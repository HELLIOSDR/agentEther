#!/bin/bash
# Spectrum Protocol 2026 - Google Drive Sync via rclone
# Synchronizes agentEther project with Google Drive

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="agentEther"

# Rclone configuration
RCLONE_REMOTE="agentether-gdrive"
GDRIVE_PATH="${RCLONE_REMOTE}:${PROJECT_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="${SCRIPT_DIR}/logs/gdrive-sync.log"
mkdir -p "${SCRIPT_DIR}/logs"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Spectrum Protocol 2026 - Google Drive Sync   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log "WARNING: $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
    log "INFO: $1"
}

check_rclone() {
    if ! command -v rclone &> /dev/null; then
        print_error "rclone is not installed!"
        echo ""
        echo "Install rclone:"
        echo "  curl https://rclone.org/install.sh | sudo bash"
        echo ""
        exit 1
    fi
    print_success "rclone is installed"
}

check_remote() {
    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:$"; then
        print_error "Remote '${RCLONE_REMOTE}' not configured!"
        echo ""
        echo "Configure rclone remote:"
        echo "  rclone config"
        echo ""
        echo "Or copy template:"
        echo "  cp .rclone.conf.template ~/.config/rclone/rclone.conf"
        echo "  # Edit with your credentials"
        echo ""
        exit 1
    fi
    print_success "Remote '${RCLONE_REMOTE}' is configured"
}

show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  backup              Backup project to Google Drive"
    echo "  restore             Restore project from Google Drive"
    echo "  sync                Bidirectional sync with Google Drive"
    echo "  status              Show sync status and differences"
    echo "  list                List files on Google Drive"
    echo "  check               Check rclone configuration"
    echo "  size                Show storage usage"
    echo ""
    echo "Options:"
    echo "  --dry-run           Show what would be transferred without doing it"
    echo "  --verbose           Show detailed output"
    echo "  --force             Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0 backup                 # Backup to Google Drive"
    echo "  $0 backup --dry-run       # Preview backup"
    echo "  $0 restore                # Restore from Google Drive"
    echo "  $0 sync                   # Bidirectional sync"
    echo "  $0 status                 # Check differences"
    echo ""
}

backup_to_gdrive() {
    local dry_run=""
    local verbose=""

    if [[ "$1" == "--dry-run" ]]; then
        dry_run="--dry-run"
        print_warning "DRY RUN MODE - No files will be transferred"
    fi

    if [[ "$1" == "--verbose" || "$2" == "--verbose" ]]; then
        verbose="-v"
    fi

    print_info "Backing up to Google Drive: ${GDRIVE_PATH}"
    print_info "Using exclude file: .rcloneignore"
    echo ""

    # Show what will be synced
    if [[ -z "$dry_run" ]]; then
        echo "Files to backup (preview):"
        rclone sync "${SCRIPT_DIR}" "${GDRIVE_PATH}" \
            --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
            --dry-run --stats-one-line 2>&1 | grep -E "Transferred:|Checks:|Deleted:" || true
        echo ""

        if [[ "$1" != "--force" && "$2" != "--force" ]]; then
            read -p "Continue with backup? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                print_warning "Backup cancelled"
                exit 0
            fi
        fi
    fi

    # Perform sync
    print_info "Starting backup..."
    rclone sync "${SCRIPT_DIR}" "${GDRIVE_PATH}" \
        --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
        --progress \
        --create-empty-src-dirs \
        --track-renames \
        --fast-list \
        $dry_run $verbose

    if [[ -z "$dry_run" ]]; then
        print_success "Backup completed successfully!"
        print_info "Remote path: ${GDRIVE_PATH}"
    fi
}

restore_from_gdrive() {
    local dry_run=""
    local verbose=""

    if [[ "$1" == "--dry-run" ]]; then
        dry_run="--dry-run"
        print_warning "DRY RUN MODE - No files will be transferred"
    fi

    if [[ "$1" == "--verbose" || "$2" == "--verbose" ]]; then
        verbose="-v"
    fi

    print_warning "RESTORE OPERATION - This will OVERWRITE local files!"
    print_info "Restoring from: ${GDRIVE_PATH}"
    echo ""

    # Show what will be restored
    if [[ -z "$dry_run" ]]; then
        echo "Files to restore (preview):"
        rclone sync "${GDRIVE_PATH}" "${SCRIPT_DIR}" \
            --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
            --dry-run --stats-one-line 2>&1 | grep -E "Transferred:|Checks:|Deleted:" || true
        echo ""

        if [[ "$1" != "--force" && "$2" != "--force" ]]; then
            read -p "Are you SURE you want to restore? (yes/NO): " confirm
            if [[ "$confirm" != "yes" ]]; then
                print_warning "Restore cancelled"
                exit 0
            fi
        fi
    fi

    # Perform restore
    print_info "Starting restore..."
    rclone sync "${GDRIVE_PATH}" "${SCRIPT_DIR}" \
        --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
        --progress \
        --create-empty-src-dirs \
        --track-renames \
        --fast-list \
        $dry_run $verbose

    if [[ -z "$dry_run" ]]; then
        print_success "Restore completed successfully!"
        print_warning "Remember to check .env and other credentials!"
    fi
}

bidirectional_sync() {
    local dry_run=""
    local verbose=""

    if [[ "$1" == "--dry-run" ]]; then
        dry_run="--dry-run"
        print_warning "DRY RUN MODE - No files will be transferred"
    fi

    if [[ "$1" == "--verbose" || "$2" == "--verbose" ]]; then
        verbose="-v"
    fi

    print_info "Bidirectional sync with Google Drive"
    print_warning "This will sync changes in BOTH directions"
    echo ""

    # Perform bisync
    print_info "Starting bidirectional sync..."
    rclone bisync "${SCRIPT_DIR}" "${GDRIVE_PATH}" \
        --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
        --create-empty-src-dirs \
        --resilient \
        --recover \
        --conflict-resolve newer \
        --conflict-loser num \
        $dry_run $verbose

    if [[ -z "$dry_run" ]]; then
        print_success "Bidirectional sync completed!"
    fi
}

show_status() {
    print_info "Checking differences between local and Google Drive..."
    echo ""

    # Compare local to remote
    echo "=== Files only in LOCAL (not on Google Drive) ==="
    rclone check "${SCRIPT_DIR}" "${GDRIVE_PATH}" \
        --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
        --one-way 2>&1 | grep "ERROR" || echo "  None"

    echo ""
    echo "=== Files only on GOOGLE DRIVE (not local) ==="
    rclone check "${GDRIVE_PATH}" "${SCRIPT_DIR}" \
        --exclude-from "${SCRIPT_DIR}/.rcloneignore" \
        --one-way 2>&1 | grep "ERROR" || echo "  None"

    echo ""
    echo "=== Size comparison ==="
    echo "Local:"
    du -sh "${SCRIPT_DIR}" | awk '{print "  " $1}'
    echo "Google Drive:"
    rclone size "${GDRIVE_PATH}" 2>&1 | grep "Total size:" | awk '{print "  " $3 " " $4}'
}

list_gdrive() {
    print_info "Files on Google Drive: ${GDRIVE_PATH}"
    echo ""
    rclone tree "${GDRIVE_PATH}" --exclude-from "${SCRIPT_DIR}/.rcloneignore"
}

show_size() {
    print_info "Storage usage analysis"
    echo ""

    echo "=== Local project size ==="
    du -sh "${SCRIPT_DIR}"
    echo ""

    echo "=== Google Drive remote size ==="
    rclone size "${GDRIVE_PATH}"
    echo ""

    echo "=== Largest directories (local) ==="
    du -h "${SCRIPT_DIR}" --max-depth=2 2>/dev/null | sort -rh | head -10
}

# Main script
print_header

# Check prerequisites
check_rclone
check_remote

# Parse command
COMMAND="${1:-}"

case $COMMAND in
    backup)
        backup_to_gdrive "$2" "$3"
        ;;
    restore)
        restore_from_gdrive "$2" "$3"
        ;;
    sync)
        bidirectional_sync "$2" "$3"
        ;;
    status)
        show_status
        ;;
    list)
        list_gdrive
        ;;
    check)
        print_success "All checks passed!"
        ;;
    size)
        show_size
        ;;
    --help|-h|help|"")
        show_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac

echo ""
log "Command completed: $COMMAND"
