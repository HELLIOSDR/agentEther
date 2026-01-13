#!/bin/bash
# Background sync daemon for coordination
# Automatically syncs state, checks for messages, and updates heartbeat

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
PID_FILE="/tmp/coordination-sync-daemon.pid"
LOG_FILE="${PROJECT_DIR}/logs/coordination-sync.log"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

ENV_NAME=$(jq -r '.environmentName' "$CONFIG_FILE")
SYNC_INTERVAL=$(jq -r '.syncInterval // 300' "$CONFIG_FILE")
HEARTBEAT_INTERVAL=$(jq -r '.heartbeatInterval // 60' "$CONFIG_FILE")

# Logging function
log() {
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" | tee -a "$LOG_FILE"
}

# Check if daemon is already running
check_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0  # Running
        else
            rm -f "$PID_FILE"
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

# Start daemon
start_daemon() {
    if check_running; then
        echo "⚠️  Daemon already running (PID: $(cat "$PID_FILE"))"
        exit 1
    fi

    echo "🚀 Starting coordination sync daemon..."
    echo "   Environment: $ENV_NAME"
    echo "   Sync interval: ${SYNC_INTERVAL}s"
    echo "   Heartbeat interval: ${HEARTBEAT_INTERVAL}s"
    echo "   Log file: $LOG_FILE"
    echo ""

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    # Start in background
    nohup "$0" _run > /dev/null 2>&1 &
    echo $! > "$PID_FILE"

    echo "✅ Daemon started (PID: $!)"
    echo ""
    echo "Commands:"
    echo "  $0 status  - Check status"
    echo "  $0 stop    - Stop daemon"
    echo "  $0 logs    - View logs"
}

# Stop daemon
stop_daemon() {
    if ! check_running; then
        echo "⚠️  Daemon not running"
        exit 0
    fi

    PID=$(cat "$PID_FILE")
    echo "🛑 Stopping daemon (PID: $PID)..."

    kill "$PID" 2>/dev/null || true

    # Wait for process to stop
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # Force kill if still running
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "⚠️  Process didn't stop gracefully, force killing..."
        kill -9 "$PID" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    echo "✅ Daemon stopped"
}

# Show status
show_status() {
    echo "═══════════════════════════════════════════"
    echo "  Coordination Sync Daemon Status"
    echo "═══════════════════════════════════════════"
    echo ""

    if check_running; then
        PID=$(cat "$PID_FILE")
        echo "Status: 🟢 Running"
        echo "PID: $PID"
        echo "Environment: $ENV_NAME"
        echo "Sync interval: ${SYNC_INTERVAL}s"
        echo "Heartbeat interval: ${HEARTBEAT_INTERVAL}s"
        echo ""

        # Show last few log lines
        if [ -f "$LOG_FILE" ]; then
            echo "Recent activity:"
            tail -5 "$LOG_FILE" | sed 's/^/  /'
        fi
    else
        echo "Status: ⚪ Not running"
    fi

    echo ""
}

# View logs
view_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "📋 No logs yet"
        exit 0
    fi

    if command -v less > /dev/null 2>&1; then
        less +G "$LOG_FILE"
    else
        tail -100 "$LOG_FILE"
    fi
}

# Main daemon loop (internal use)
run_daemon() {
    log "🚀 Coordination sync daemon started (PID: $$)"
    log "   Environment: $ENV_NAME"
    log "   Sync interval: ${SYNC_INTERVAL}s"
    log "   Heartbeat interval: ${HEARTBEAT_INTERVAL}s"

    # Counters
    sync_counter=0
    heartbeat_counter=0

    # Trap signals for graceful shutdown
    trap 'log "📴 Daemon stopping..."; exit 0' SIGTERM SIGINT

    while true; do
        # Heartbeat
        if [ $((heartbeat_counter % HEARTBEAT_INTERVAL)) -eq 0 ]; then
            log "💓 Sending heartbeat..."
            "${SCRIPT_DIR}/update-state.sh" --heartbeat >> "$LOG_FILE" 2>&1 || log "❌ Heartbeat failed"
        fi

        # Full sync
        if [ $((sync_counter % SYNC_INTERVAL)) -eq 0 ]; then
            log "🔄 Starting sync cycle..."

            # Sync to Google Drive
            log "  ☁️  Syncing to Google Drive..."
            "${PROJECT_DIR}/sync-gdrive.sh" >> "$LOG_FILE" 2>&1 && \
                log "  ✅ Google Drive sync complete" || \
                log "  ❌ Google Drive sync failed"

            # Check for new messages
            NEW_MESSAGES=$(find "${SCRIPT_DIR}/messages" -name "*.json" -type f -newer "${SCRIPT_DIR}/state.json" 2>/dev/null | wc -l)
            if [ "$NEW_MESSAGES" -gt 0 ]; then
                log "  📬 Found $NEW_MESSAGES new message(s)"

                # Optional: Send desktop notification
                if command -v notify-send > /dev/null 2>&1; then
                    notify-send "Claude Coordination" "You have $NEW_MESSAGES new message(s)"
                fi
            fi

            # Sync to ChromaDB (optional)
            if command -v python3 > /dev/null 2>&1 && [ -f "${SCRIPT_DIR}/chromadb-sync.py" ]; then
                log "  🗄️  Syncing to ChromaDB..."
                python3 "${SCRIPT_DIR}/chromadb-sync.py" sync >> "$LOG_FILE" 2>&1 && \
                    log "  ✅ ChromaDB sync complete" || \
                    log "  ⚠️  ChromaDB sync skipped (service may be unavailable)"
            fi

            log "✅ Sync cycle complete"
        fi

        # Increment counters
        heartbeat_counter=$((heartbeat_counter + 1))
        sync_counter=$((sync_counter + 1))

        # Sleep for 1 second
        sleep 1
    done
}

# Parse command
case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 2
        start_daemon
        ;;
    status)
        show_status
        ;;
    logs)
        view_logs
        ;;
    _run)
        # Internal: run the daemon loop
        run_daemon
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the sync daemon"
        echo "  stop     - Stop the sync daemon"
        echo "  restart  - Restart the sync daemon"
        echo "  status   - Show daemon status"
        echo "  logs     - View daemon logs"
        exit 1
        ;;
esac
